# Vision Score 👷

**Prototype for extracting interpretable construction-site safety indicators from images.**

The motivation is to examine whether visible on-site safety evidence can complement high-level ESG workplace-safety evaluations.

> **Limitation:** Computed scores are *heuristic demo indicators*, not certified safety assessments, official ESG ratings, or predictions of future accidents.

## Implemented components

- **Vision backend:** external pretrained YOLO models for fire/smoke and selected person/PPE/machinery/vehicle detections.
- **Scoring:** `main.py` calculates example scores based on hardhat/vest observations, fire/smoke, vehicles, and the pixel distance between people and machinery.
- **API:** FastAPI endpoint for uploaded images and result images.
- **Client:** Flutter prototype in `codes/`.

**Distance in image pixels is not actual real-world proximity** without camera calibration. These rules have not been clinically or industrially validated.

## Repository layout

| Path | Contents |
| --- | --- |
| `main.py` | Detection, scoring and API |
| `requirements.txt` | Python dependencies |
| `codes/` | Flutter application |
| `demo/` | Demo media |
| `Dockerfile` | Backend container setup |

## Run backend locally

```bash
git clone https://github.com/minjoooo303/visionscore.git
cd visionscore
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload
```

At startup, the backend downloads external pretrained model weights if missing. Internet access, compatible ML packages, and model availability are required.

See [codes/pubspec.yaml](codes/pubspec.yaml) for the Flutter client's dependencies.

## What remains

- Evaluate detection and scoring on representative labeled data
- Calibrate physical distances, if proximity is to be used operationally
- Strengthen privacy and security for uploaded images
- Validate thresholds with domain experts

The original [problem-definition illustration](https://github.com/user-attachments/assets/89d43629-c26d-49b3-8058-0414c8029e00) motivated this demo.
