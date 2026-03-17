import sys
import json
import vertexai
from vertexai.preview.reasoning_engines import ReasoningEngine

vertexai.init(project="saeed-demo-proj", location="us-central1")
engine_id = "projects/941446881468/locations/us-central1/reasoningEngines/1596771258995834880"

print("Connecting to live engine...", engine_id)
try:
    engine = ReasoningEngine(engine_id)
    response = engine.query(
        image_uri="gs://saeed-demo-proj.firebasestorage.app/photos/euuK9uowLNd134saFlexiG3zu9b2/1773667113527.jpg",
        diseases="Gout, Hypertension"
    )
    print("LIVE RESPONSE:")
    print(json.dumps(response, indent=2))
except Exception as e:
    print("Error:", e)
