# Dietary Recommendation AI App

A novel, AI-powered Flutter web application that analyzes images of food and restaurant menus to provide personalized, medically sound dietary recommendations based on a user's specific health condition (e.g., Diabetic, High Blood Pressure, Gout).

The app leverages Google Cloud's **Vertex AI Reasoning Engine (Gemini 2.5 Flash)** to analyze uploaded images and assess whether the food is safe to eat, returning a color-coded evaluation along with a detailed medical reasoning summary and healthier alternative suggestions.

---

## ✨ Key Features (Recent Updates)

- **📊 Behavioral Scoring Dashboard**: Aggregates your historical eating behavior trends into a floating numerical score right on top of the History tab.
- **📈 Timeline Line Charting**: Visually curves your clinical adherence over time in chronological graphs, warning you if your average dives into dangerous thresholds.
- ** Snappy UX dismissal Actions**: Log compliance interactively with click-and-snap interactive widgets ensuring fast-cleared background database sync runs flawlessly invisibly.

---

## 🏗️ Architecture

The project consists of three main tightly integrated components:

1. **Frontend (Flutter)**: A cross-platform Flutter application (optimized for Web) that captures images, allows disease selection, uploads the image to Cloud Storage, and displays the AI results in an expandable color-coded UI.
2. **Cloud Functions (Firebase)**: A serverless backend endpoint that acts as the secure intermediary. It takes the Storage URI and the disease string from the Flutter app and passes it securely to Vertex AI.
3. **Reasoning Engine (Vertex AI)**: A dedicated Python Agent running `gemini-2.5-flash` that is explicitly prompted to act as an expert medical dietician. It analyzes the image and returns a strictly formatted JSON payload with the evaluation.
4. **Firestore (Database)**: Operates as the long-term historical structure that stores AI analyses and tracks user behavioral decisions.

### Data Flow
1. User selects a disease and uploads an image in the **Flutter App**.
2. The image is uploaded as raw bytes to **Firebase Storage**.
3. Flutter triggers the `analyze_image` **Firebase Cloud Function**, passing the Storage URI and selected disease.
4. The Cloud Function calls the **Vertex AI Reasoning Engine** using the Python SDK.
5. The `ImageAnalyzerAgent` prompts Gemini 2.5 Flash, returning a JSON evaluation.
6. The Cloud Function returns this JSON to Flutter, and creates a log document in **Firestore**.
7. Flutter parses the JSON and presents a color-coded UI result bottom sheet to the user.
8. User interacts with **Eat It** or **Pass** buttons, triggering a background update directly to the **Firestore** document to track dietary behavior compliance.

---

## 🗂️ Project Structure

```text
photo_upload_app/
├── lib/
│   ├── main.dart             # Main Flutter UI (Camera, Display, Behavior Dashboards)
│   └── firebase_options.dart # Generated Firebase configuration keys
├── functions/
│   ├── main.py               # Firebase Cloud Function (Serverless Middleware)
│   └── requirements.txt      # Cloud Function dependencies
├── backend/
│   ├── pyproject.toml        # Python packaging configurations
│   ├── dietary_agent/        # Core Multi-Agent Logic
│   │   ├── agent.py          # Vertex AI Reasoning Engine / ADK wrapper
│   │   ├── prompt.txt         # Medical synthesis prompting pipeline
│   │   └── sub_agents/       # Specialist nodes configured in deployment
│   │       ├── clinical_agent.py # Evaluates ingredients against medical profiles
│   │       └── vision_agent.py   # Identifies exact ingredients from image stream
│   └── deployment/           # Deployment Logic
│       └── deploy.py         # Script to package & serve the agent to Vertex
├── firebase.json             # Firebase deployment configuration
├── firestore.rules            # Firestore database security rules (enables tracking)
└── storage.rules              # Firebase Storage security rules
```

---

## 🚀 Setup & Installation Guide

This guide assumes you are setting this up from scratch on a new local machine or Google Cloud Project.

### Prerequisites

1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. Install [Python 3.10+](https://www.python.org/downloads/).
3. Install the [Firebase CLI](https://firebase.google.com/docs/cli).
4. Install the [Google Cloud CLI (`gcloud`)](https://cloud.google.com/sdk/docs/install) and authenticate: `gcloud auth login`.

### 1. Google Cloud Project Setup
1. Create a new Google Cloud Project.
2. Enable the following APIs via the GCP Console:
   - Vertex AI API (`aiplatform.googleapis.com`)
   - Cloud Functions API (`cloudfunctions.googleapis.com`)
   - Cloud Run API (`run.googleapis.com`)
   - Artifact Registry API (`artifactregistry.googleapis.com`)
3. Initialize a Firebase project in your GCP project via the Firebase Console.
4. Set up Firebase Storage in the console.

### 2. Deploy the Vertex AI Reasoning Engine
The Reasoning Engine requires deploying the python class so it runs persistently on Google's AI servers.

1. Navigate to the agent directory:
   ```bash
   cd backend/agent
   ```
2. Create and activate a virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Authenticate your application-default credentials:
   ```bash
   gcloud auth application-default login
   ```
5. Deploy the agent. Provide your Project ID and a Cloud Storage bucket for staging the deployment artifacts:
   ```bash
   python3 deploy.py --project YOUR_PROJECT_ID --bucket gs://YOUR_STAGING_BUCKET_NAME
   ```
6. **IMPORTANT:** Note the newly generated `Agent ID` (e.g., `projects/.../reasoningEngines/123456789`). This is saved automatically in `agent_id.txt`.

### 3. Deploy the Firebase Cloud Function
The Cloud Function wraps the Vertex AI call so that the Mobile/Web app doesn't need direct IAM permissions to your AI endpoints.

1. Open `functions/main.py` and update the `AGENT_RESOURCE_NAME` variable on line 8 with the newly generated Agent ID from the previous step.
2. Deploy the functions and storage rules via Firebase CLI:
   ```bash
   firebase use --add YOUR_PROJECT_ID
   firebase deploy --only functions,storage
   ```
3. *(Optional for Dev)* If you face "Unauthenticated" errors invoking the final Cloud Function, you may need to grant `allUsers` the `Cloud Run Invoker` role for the `analyze-image` underlying Cloud Run service in the GCP Console.

### 4. Run the Flutter Web App
1. Ensure the Flutter app is linked to your Firebase project by running `flutterfire configure`, which will generate/update `lib/firebase_options.dart`.
2. Run the application locally on the web:
   ```bash
   flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080
   ```
3. Open your browser to `http://localhost:8080`.

---

## 📝 Usage

1. **Select a condition:** Use the radio buttons to choose an underlying medical condition (e.g., Gout).
2. **Upload:** Click the camera icon or "Take/Upload Photo" to attach an image of food or a restaurant menu.
3. **Analyze:** The image bytes and disease string are sent to Firebase Storage and Cloud Functions.
4. **Result:** An expansion sheet slides up. Follow the Green/Yellow/Red indicator to immediately see if the food is suitable, and expand the details to see the medical reasoning and healthier alternatives provided by Vertex AI.
