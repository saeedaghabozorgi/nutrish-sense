from firebase_functions import https_fn, options
from firebase_admin import initialize_app
import vertexai
from vertexai.preview.reasoning_engines import ReasoningEngine
import json
import traceback

initialize_app()

# We will dynamically query Vertex AI to find the latest active engine instance.
# To prevent excessive API calls, the result is cached per Cloud Function instance lifetime.
_cached_engine_id = None

def get_latest_engine() -> str:
    global _cached_engine_id
    if _cached_engine_id:
        return _cached_engine_id
        
    print("Stage 0: Cold start - Querying Vertex AI for latest 'Multi-Agent ADK Dietician' engine...")
    vertexai.init(project="saeed-demo-proj", location="us-central1")
    engines = filter(
        lambda e: e.display_name and e.display_name.startswith("Multi-Agent ADK Dietician"),
        ReasoningEngine.list()
    )
    
    # Sort by creation time descending (newest first)
    sorted_engines = sorted(
        list(engines), 
        key=lambda x: x.create_time, 
        reverse=True
    )
    
    if not sorted_engines:
        raise RuntimeError("No active 'Multi-Agent ADK Dietician' Reasoning Engine found in project.")
        
    _cached_engine_id = sorted_engines[0].resource_name
    print(f"Loaded active engine: {sorted_engines[0].display_name} ({_cached_engine_id})")
    return _cached_engine_id

@https_fn.on_call(
    region="us-central1",
    memory=options.MemoryOption.GB_1,
    timeout_sec=120,
    enforce_app_check=False,
    service_account="dietary-app-backend@saeed-demo-proj.iam.gserviceaccount.com"
)
def analyze_image(req: https_fn.CallableRequest) -> dict:
    """Triggered by the Flutter app via Callable functions."""
    print("Stage 1: analyze_image function triggered.")
    
    # 1. Enforce Authentication
    if req.auth is None:
        print("Error: Unauthenticated request.")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, 
            message="Must be logged in to analyze images."
        )

    # 2. Extract and Validate GCS URI Ownership
    gcs_uri = req.data.get("gcs_uri")
    if not gcs_uri:
        print("Error: Missing gcs_uri in request.")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Missing gcs_uri"
        )
        
    print(f"Stage 2: GCS URI validated: {gcs_uri}")
    user_uid = req.auth.uid
    expected_path_segment = f"/photos/{user_uid}/"
    if expected_path_segment not in gcs_uri:
        print(f"Error: Permission denied for GCS URI {gcs_uri} (User: {user_uid}).")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
            message="You do not have permission to analyze this image."
        )

    # 3. Validate Disease Input (Anti-Prompt Injection)
    allowed_diseases = [
        "Diabetic", 
        "High Blood Pressure", 
        "Gout", 
        "Healthy adult (General Nutrition)"
    ]
    raw_disease = req.data.get("disease", "Healthy adult (General Nutrition)")
    
    # Split by comma, check if allowed
    selected = [d.strip() for d in raw_disease.split(",")]
    valid_diseases = [d for d in selected if d in allowed_diseases]
    
    if not valid_diseases:
        disease = "Healthy adult (General Nutrition)"
    else:
        disease = ", ".join(valid_diseases)

    try:
        # Connect to Vertex AI Agent Engines API
        active_agent_resource_name = get_latest_engine()
        print(f"Stage 3: Calling Vertex AI Agent Engine ({active_agent_resource_name})...")
        client = vertexai.Client(project="saeed-demo-proj", location="us-central1")
        adk_app = client.agent_engines.get(name=active_agent_resource_name)
        
        lab_results = req.data.get("labResults", "")
        medications = req.data.get("medications", "")
        allergies = req.data.get("allergies", "")
        activity_level = float(req.data.get("activityLevel", 0.0))

        context_vars = {
            "lab_results": lab_results,
            "medications": medications,
            "allergies": allergies,
            "activity_level": activity_level
        }
        context = "\n".join([f"{k.replace('_', ' ').title()}: {v}" for k, v in context_vars.items() if v])
        prompt = f"Analyze this image for a patient with: {disease}\n{context}"
        
        from google.genai.types import UserContent, Part
        import asyncio
        import uuid
        
        # In the ADK, the client expects dictionaries for the message
        prompt_msg = {
            "role": "user",
            "parts": [
                {"file_data": {"file_uri": gcs_uri, "mime_type": "image/jpeg"}},
                {"text": prompt}
            ]
        }
        
        async def run_query():
            text_result = ""
            uid = f"user_{str(uuid.uuid4())}"
            try:
                # Call standard ADK stream query
                async for event in adk_app.async_stream_query(
                    user_id=uid,
                    message=prompt_msg
                ):
                    print(event)
                    # The event comes back as a dict over the wire via the client API
                    if 'content' in event and 'parts' in event['content']:
                        for part in event['content']['parts']:
                            if 'text' in part:
                                text_result += part['text']
            except Exception as e:
                print(f"Stream query error: {e}")
                raise e
            return text_result
        
        text_response = asyncio.run(run_query())
        
        print(f"Stage 4: Received response from AI agent: {text_response}")
        final_text = text_response
        
        if isinstance(final_text, str):
            try:
                trimmed = final_text.strip()
                if trimmed.startswith('```json'): trimmed = trimmed[7:]
                if trimmed.endswith('```'): trimmed = trimmed[:-3]
                final_text = json.loads(trimmed.strip())
            except Exception as parse_e:
                print(f"Warning: Failed to parse response as JSON string. {parse_e}")
                pass

        return {"result": final_text}

    except Exception as e:
        print("CRITICAL: Error calling ADK agent!")
        traceback.print_exc()
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="An internal error occurred."
        )
