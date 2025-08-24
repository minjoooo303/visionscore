from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse, FileResponse
import uvicorn
import os
from ultralytics import YOLO
import shutil
import base64
from pydantic import BaseModel
import math
import numpy as np
from ultralytics.utils.plotting import Annotator, colors
import cv2
import mimetypes

app = FastAPI()
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],      # 필요시 특정 도메인으로 제한
    allow_methods=["*"],
    allow_headers=["*"],
)



# ===== 모델 로드 =====

import os, requests

HF_MODEL1_URL = os.getenv(
    "MODEL1_URL",
    # fire/smoke
    "https://huggingface.co/leeyunjai/yolo11-firedetect/resolve/main/firedetect-11x.pt?download=true"
)
HF_MODEL2_URL = os.getenv(
    "MODEL2_URL",
    # PPE/person/machinery/vehicle
    "https://huggingface.co/yihong1120/Construction-Hazard-Detection-YOLO11/resolve/main/models/pt/best_yolo11x.pt?download=true"
)

def ensure_weight(url: str, dst: str):
    if os.path.exists(dst):
        return dst
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    print(f"[download] {url} -> {dst}")
    with requests.get(url, stream=True, timeout=60) as r:
        r.raise_for_status()
        with open(dst, "wb") as f:
            for chunk in r.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
    return dst

# 여기에 실제 저장 경로(앱 상대경로)를 고정
MODEL1_PATH = ensure_weight(HF_MODEL1_URL, "models/pt/firedetect-11x.pt")
MODEL2_PATH = ensure_weight(HF_MODEL2_URL, "models/pt/best_yolo11x.pt")


try:
    # model1: Fire/Smoke
    model1 = YOLO(MODEL1_PATH)
    # model2: Person/PPE/machinery/vehicle
    model2 = YOLO(MODEL2_PATH)
except Exception as e:
    print(f"Error loading YOLO models: {e}")
    model1 = None
    model2 = None

# ===== 데이터 모델 =====
class ScoreDetails(BaseModel):
    hardhat: float | None = None
    safety_vest: float | None = None
    machinery_distance: float | None = None
    vehicle: float | None = None
    person_count: float | None = None
    fire_and_smoke: float | None = None

class ScoreResponse(BaseModel):
    total_score: float
    details: ScoreDetails
    result_file: str
    result_image_base64: str | None = None
    original_image_name: str | None = None
    original_video_name: str | None = None

# ===== 라벨 정규화 & 선택 유틸 =====
def _norm(s: str) -> str:
    return s.lower().replace("-", "").replace("_", "").strip()

def filter_boxes_by_alias(results, names: dict, aliases: list[str]):
    """
    results: list[Results] 또는 [] (Ultralytics predict 반환 형태)
    names:   {cls_id:int -> name:str}
    aliases: 매칭하고 싶은 라벨 이름 후보들
    -> aliases 중 하나와 매칭되는 박스들만 리스트로 반환
    """
    want = {_norm(a) for a in aliases}
    out = []
    if results and results[0] is not None and getattr(results[0], "boxes", None) is not None:
        r = results[0]
        n = len(r.boxes)
        for i in range(n):
            cls_id = int(r.boxes.cls[i])
            name = names.get(cls_id, str(cls_id))
            if _norm(name) in want:
                out.append(r.boxes[i])
    return out

# ===== 점수 계산 (모델 분리) =====
def calculate_score(res_fire, res_ppe, names_fire: dict, names_ppe: dict):
    """
    res_fire : model1 결과(Fire/Smoke)
    res_ppe  : model2 결과(Person/PPE/machinery/vehicle)
    names_*  : 각 모델의 names(dict)
    """
    fires   = filter_boxes_by_alias(res_fire, names_fire, ["fire"])
    smokes  = filter_boxes_by_alias(res_fire, names_fire, ["smoke"])

    persons         = filter_boxes_by_alias(res_ppe, names_ppe, ["person"])
    no_hardhats     = filter_boxes_by_alias(res_ppe, names_ppe, ["no-hardhat", "nohardhat"])
    no_safety_vests = filter_boxes_by_alias(res_ppe, names_ppe, ["no-safety vest", "nosafetyvest"])
    machineries     = filter_boxes_by_alias(res_ppe, names_ppe, ["machinery"])
    vehicles        = filter_boxes_by_alias(res_ppe, names_ppe, ["vehicle"])


    total_persons = len(persons)
    nv      = len(vehicles)
    nfires  = len(fires)
    nsmokes = len(smokes)

    # 안전 초기화
    r_h = 0.0
    r_v = 0.0
    min_distance = None
    D_th = 500  # 거리 임계(px)

    # 1. 안전모
    if total_persons > 0:
        r_h = len(no_hardhats) / total_persons
        score_hardhat = max(0, 10 - r_h * 10)
    else:
        score_hardhat = 10.0

    # 2. 조끼
    if total_persons > 0:
        r_v = len(no_safety_vests) / total_persons
        score_safety_vest = max(0, 10 - r_v * 10)
    else:
        score_safety_vest = 10.0

    # 3. 중장비-사람 거리 (픽셀 기준 가정)
    if persons and machineries:
        min_distance = float('inf')
        for p in persons:
            p_center = p.xywh[0].cpu().numpy()[:2]
            for m in machineries:
                m_center = m.xywh[0].cpu().numpy()[:2]
                d = np.linalg.norm(p_center - m_center)
                if d < min_distance:
                    min_distance = d
        D_th = 500
        score_machinery_distance = max(0, 10 - math.ceil(max(0, D_th - min_distance) / 50))
    else:
        score_machinery_distance = 10.0

    # 4. 차량 수
    nv = len(vehicles)
    score_vehicle = 10.0 if nv == 0 else 7.0 if nv == 1 else 4.0 if nv == 2 else 0.0

    # 5. 사람 수
    npers = total_persons
    if npers == 0 or npers >= 5:
        score_person_count = 10.0
    elif npers == 1:
        score_person_count = 0.0
    elif npers == 2:
        score_person_count = 4.0
    elif npers == 3:
        score_person_count = 6.0
    else:
        score_person_count = 8.0

    # 6. 화재/연기
    score_fire_smoke = 0.0 if (fires or smokes) else 10.0

    total_score = (score_hardhat + score_safety_vest + score_machinery_distance +
                   score_vehicle + score_person_count ) # + score_fire_smoke)

    # === 설명문 생성(간단 규칙) ===
    reasons = []
    if total_persons == 0:
        reasons.append("사람이 감지되지 않아 안전모 착용 항목은 만점으로 처리되었습니다.")
        reasons.append("사람이 감지되지 않아 안전조끼 착용 항목은 만점으로 처리되었습니다.")
    else:
        reasons.append(f"사람 {total_persons}명 중 안전모 미착용 {len(no_hardhats)}명 (비율 {r_h:.0%})")
        reasons.append(f"사람 {total_persons}명 중 안전조끼 미착용 {len(no_safety_vests)}명 (비율 {r_v:.0%})")
    if min_distance is not None:
        reasons.append(f"사람-중장비 최소 거리 {int(min_distance)}px (임계 {D_th}px)")
    else:
        reasons.append("중장비 또는 사람이 없어 거리 위험 없음")
    reasons.append(f"차량 {nv}대 감지")
    reasons.append(f"사람 {npers}명 감지")
  
    metrics = {
        "counts": {
            "persons": total_persons,
            "no_hardhat": len(no_hardhats),
            "no_safety_vest": len(no_safety_vests),
            "machineries": len(machineries),
            "vehicles": nv,
            "fires": nfires,
            "smokes": nsmokes,
        },
        "ratios": {
            "no_hardhat_per_person": round(r_h, 3) if total_persons else 0.0,
            "no_safety_vest_per_person": round(r_v, 3) if total_persons else 0.0,
        },
        "distance_px": {
            "min_person_machinery": None if min_distance is None else round(min_distance, 1),
            "threshold_px": D_th,
        },
         # ★ 새로 추가: 각 항목별 점수
        "scores": {
            "hardhat": round(score_hardhat, 2),
            "safety_vest": round(score_safety_vest, 2),
            "machinery_distance": round(score_machinery_distance, 2),
            "vehicle": round(score_vehicle, 2),
            "person_count": round(score_person_count, 2),
            "fire_and_smoke": round(score_fire_smoke, 2),
            "total": round(total_score, 2),  # 총점도 참고용으로 넣어둠
        },
    }

    return {
        "total_score": float(round(total_score, 2)),
        "details": {
            "hardhat": float(round(score_hardhat, 2)),
            "safety_vest": float(round(score_safety_vest, 2)),
            "machinery_distance": float(round(score_machinery_distance, 2)),
            "vehicle": float(round(score_vehicle, 2)),
            "person_count": float(round(score_person_count, 2)),
            "fire_and_smoke": float(round(score_fire_smoke, 2)),
        },
        "metrics": {
            "counts": {k: float(v) for k, v in metrics["counts"].items()},
            "ratios": {k: float(v) for k, v in metrics["ratios"].items()},
            "distance_px": {k: float(v) if v is not None else None for k, v in metrics["distance_px"].items()},
            "scores": {k: float(v) for k, v in metrics["scores"].items()},
        },
        "explain": "\n".join(reasons),
    }


# ===== 그리기 유틸: 각 모델 결과를 동일 이미지/프레임에 누적 =====
def draw_results_on_annotator(annotator: Annotator, results, names: dict):
    if results and results[0] is not None and getattr(results[0], "boxes", None) is not None:
        r = results[0]
        n = len(r.boxes)
        for i in range(n):
            b = r.boxes.xyxy[i]
            c = int(r.boxes.cls[i])
            conf = float(r.boxes.conf[i]) if r.boxes.conf is not None else 0.0
            label = f"{names.get(c, str(c))} {conf:.2f}"
            annotator.box_label(b, label, color=colors(c, True))

# ===== 헬스체크 =====
@app.get("/")
def health():
    return {
        "ok": True,
        "endpoints": [
            "POST /detect-fire-and-score/",
            "GET  /get-result/{filename}",
            "GET  /get-original-image/{filename}",
            "GET  /docs"
        ]
    }

# ===== 메인 엔드포인트 =====
@app.post("/detect-fire-and-score/")
async def detect_fire_and_score(file: UploadFile = File(...)):
    if model1 is None or model2 is None:
        raise HTTPException(status_code=500, detail="YOLO models not loaded.")

    try:
        upload_dir = "uploads"
        os.makedirs(upload_dir, exist_ok=True)
        # 파일명 sanitize
        orig_name = os.path.basename(file.filename)
        file_location = os.path.join(upload_dir, orig_name)
        with open(file_location, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # 이미지/비디오 판별
        mime, _ = mimetypes.guess_type(file_location)
        ext = os.path.splitext(orig_name)[1].lower()
        is_video = (mime and mime.startswith("video/")) or ext in [".mp4", ".mov", ".avi", ".mkv", ".webm", ".m4v"]

        # ---------- 이미지 ----------
        if not is_video:
            results1 = model1.predict(source=file_location, save=False, imgsz=640, conf=0.25)
            results2 = model2.predict(source=file_location, save=False, imgsz=640, conf=0.25)

            # 점수 계산 (모델별로 해석)
            score_data = calculate_score(results1, results2, model1.names, model2.names)

            # 그리기 (두 모델 결과를 같은 이미지에 누적)
            img = cv2.imread(file_location)
            if img is None:
                raise HTTPException(status_code=400, detail="Failed to read the uploaded image.")
            ann = Annotator(img, line_width=2)
            draw_results_on_annotator(ann, results1, model1.names)  # Fire/Smoke
            draw_results_on_annotator(ann, results2, model2.names)  # Person/PPE/등
            img_out = ann.result()

            stem = os.path.splitext(orig_name)[0]
            result_img_path = os.path.join(upload_dir, f"result_{stem}.png")
            cv2.imwrite(result_img_path, img_out)

            with open(result_img_path, "rb") as image_file:
                encoded_image = base64.b64encode(image_file.read()).decode("utf-8")

            return JSONResponse(content={
                "total_score": score_data["total_score"],
                "details": score_data["details"],
                "metrics": score_data["metrics"],      # ★ 추가
                "explain": score_data["explain"],      # ★ 추가
                "result_file": f"uploads/result_{stem}.png",
                "result_image_base64": encoded_image,
                "original_image_name": orig_name
            })

        # ---------- 동영상 ----------
        cap = cv2.VideoCapture(file_location)
        if not cap.isOpened():
            raise HTTPException(status_code=400, detail="Failed to open the uploaded video.")

        fps = cap.get(cv2.CAP_PROP_FPS) or 25.0
        w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

        stem = os.path.splitext(orig_name)[0]
        result_video_path = os.path.join(upload_dir, f"result_{stem}.mp4")
        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        out = cv2.VideoWriter(result_video_path, fourcc, fps, (w, h))

        total_scores: list[float] = []
        # ▲ 세부 점수 평균용
        agg_details = {
            "hardhat": 0.0, "safety_vest": 0.0, "machinery_distance": 0.0,
            "vehicle": 0.0, "person_count": 0.0, "fire_and_smoke": 0.0
        }
        # ▲ 카운트 누적용
        agg_counts = {"persons":0,"no_hardhat":0,"no_safety_vest":0,
                      "machineries":0,"vehicles":0,"fires":0,"smokes":0}
        # ▲ 최소 거리(프레임 전체에서 최솟값)
        min_dist_px = None

        frame_cnt = 0

        while True:
            ret, frame = cap.read()
            if not ret:
                break

            # 각 프레임 추론
            boxes_data_1 = None
            for r in model1.predict(source=frame, imgsz=640, conf=0.25, save=False, stream=True):
                if r.boxes is not None and len(r.boxes) > 0:
                    boxes_data_1 = r
            boxes_data_2 = None
            for r in model2.predict(source=frame, imgsz=640, conf=0.25, save=False, stream=True):
                if r.boxes is not None and len(r.boxes) > 0:
                    boxes_data_2 = r

            res_fire = [boxes_data_1] if boxes_data_1 is not None else []
            res_ppe  = [boxes_data_2] if boxes_data_2 is not None else []

            # ▲ 프레임별 점수/메트릭
            score_frame = calculate_score(res_fire, res_ppe, model1.names, model2.names)

            # ▲ 누적
            total_scores.append(score_frame["total_score"])
            for k in agg_details:
                agg_details[k] += score_frame["details"][k]

            mf = score_frame["metrics"]["counts"]
            for k in agg_counts:
                agg_counts[k] += int(mf.get(k, 0))

            dpx = score_frame["metrics"]["distance_px"]["min_person_machinery"]
            if dpx is not None:
                min_dist_px = dpx if (min_dist_px is None or dpx < min_dist_px) else min_dist_px

            # 그리기
            ann = Annotator(frame, line_width=2)
            draw_results_on_annotator(ann, res_fire, model1.names)
            draw_results_on_annotator(ann, res_ppe,  model2.names)
            out.write(ann.result())

            frame_cnt += 1

        cap.release()
        out.release()

        if frame_cnt > 0:
            avg_details = {k: round(agg_details[k]/frame_cnt, 2) for k in agg_details}
            avg_score = round(sum(total_scores) / frame_cnt, 2)

            # numpy.float32 -> float으로 확실히 변환
            avg_score = float(avg_score)
            for k, v in avg_details.items():
                if v is not None:
                    avg_details[k] = float(v)

            video_metrics = {
                "counts_avg_per_frame": {k: float(round(agg_counts[k]/frame_cnt, 2)) for k in agg_counts},
                "distance_px": {
                    "min_person_machinery_min_overall": None if min_dist_px is None else float(round(min_dist_px, 1)),
                    "threshold_px": 500
                },
                "scores": {
                "hardhat":         float(avg_details["hardhat"]),
                "safety_vest":     float(avg_details["safety_vest"]),
                "machinery_distance": float(avg_details["machinery_distance"]),
                "vehicle":         float(avg_details["vehicle"]),
                "person_count":    float(avg_details["person_count"]),
                "fire_and_smoke":  float(avg_details["fire_and_smoke"]),
                "total":           float(avg_score),
                },
            }
            reasons = []
            persons = int(video_metrics['counts_avg_per_frame']['persons'])
            vehicles = int(video_metrics['counts_avg_per_frame']['vehicles'])
            no_hardhat = int(video_metrics['counts_avg_per_frame']['no_hardhat'])
            no_vest = int(video_metrics['counts_avg_per_frame']['no_safety_vest'])
            min_distance = video_metrics['distance_px']['min_person_machinery_min_overall']
            D_th = video_metrics['distance_px']['threshold_px']

            # 사람 관련 (평균 기준)
            if persons > 0:
                if no_hardhat > 0:
                    r_h = no_hardhat / persons
                    reasons.append(f"평균 사람 {persons}명 중 안전모 미착용 {no_hardhat}명 (비율 {r_h:.0%})")
                else:
                    reasons.append(f"평균 사람 {persons}명 모두 안전모 착용")

                if no_vest > 0:
                    r_v = no_vest / persons
                    reasons.append(f"평균 사람 {persons}명 중 안전조끼 미착용 {no_vest}명 (비율 {r_v:.0%})")
                else:
                    reasons.append(f"평균 사람 {persons}명 모두 안전조끼 착용")
            else:
                reasons.append("사람이 감지되지 않아 안전모 착용 항목은 만점으로 처리되었습니다.")
                reasons.append("사람이 감지되지 않아 안전조끼 착용 항목은 만점으로 처리되었습니다.")

            # 거리 관련 (최소 거리 값)
            if persons > 0 and (min_distance is not None):
                reasons.append(f"사람-중장비 최소 거리 {int(min_distance)}px (임계 {D_th}px)")
            else:
                reasons.append("중장비 또는 사람이 없어 거리 위험 없음")

         
            reasons.append(f"평균 차량 {vehicles}대 감지")

            reasons.append(f"평균 사람 {persons}명 감지")
            

            # 최종 설명
            video_explain = "\n".join(reasons)
        else:
            avg_details = {k: None for k in agg_details}
            avg_score = 0.0
            video_metrics = {"counts_avg_per_frame": agg_counts, "distance_px": {"min_person_machinery_min_overall": None, "threshold_px": 500}}
            video_explain = "프레임을 읽지 못했습니다."

        return JSONResponse(content={
            "total_score": avg_score,
            "details": avg_details,
            "metrics": video_metrics,
            "explain": video_explain,
            "result_file": f"{result_video_path}",
            "original_video_name": orig_name
        })

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An error occurred: {e}")

# ===== 파일 다운로드 =====
@app.get("/get-result/{filename}")
async def get_result_file(filename: str):
    path = os.path.join("uploads", os.path.basename(filename))
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="Result file not found.")
    return FileResponse(path)

@app.get("/get-original-image/{filename}")
async def get_original_image(filename: str):
    path = os.path.join("uploads", os.path.basename(filename))
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="Original image not found.")
    return FileResponse(path)

if __name__ == "__main__":

    uvicorn.run(app, host="0.0.0.0", port=8000)
    

