from firebase_functions import https_fn, options
from firebase_admin import initialize_app
import vertexai
from vertexai.preview.reasoning_engines import ReasoningEngine

initialize_app()

AGENT_RESOURCE_NAME = "projects/941446881468/locations/us-central1/reasoningEngines/1404453481158279168"

@https_fn.on_call(
    region="us-central1",
    memory=options.MemoryOption.MB_512,
    timeout_sec=60
)
def analyze_image(req: https_fn.CallableRequest) -> dict:
    """Triggered by the Flutter app via Callable functions."""
    
    # Check if user is authenticated (Commented out temporarily to ease testing without strict auth rules set locally)
    # if req.auth is None:
    #     raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message="Must be logged in.")

    gcs_uri = req.data.get("gcs_uri")
    if not gcs_uri:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Missing gcs_uri"
        )
        
    try:
        # Connect to Vertex AI Reasoning Engine API
        vertexai.init(project="saeed-demo-proj", location="us-central1")
        remote_agent = ReasoningEngine(AGENT_RESOURCE_NAME)
        
        # Call our query method that we deployed in `agent.py`
        text_response = remote_agent.query(
            gcs_uri=gcs_uri,
            prompt="Analyze this image. What is it?"
        )
        
        return {"result": text_response}

    except Exception as e:
        print(f"Error calling ADK agent: {e}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="An internal error occurred."
        )
