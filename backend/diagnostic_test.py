import argparse
import vertexai
from vertexai.preview.reasoning_engines import ReasoningEngine

def test_agent(agent_id: str, project: str, location: str):
    print(f"--- Diagnostic Test Starting ---")
    print(f"Project: {project}")
    print(f"Location: {location}")
    print(f"Agent ID: {agent_id}")
    
    vertexai.init(project=project, location=location)
    
    try:
        print("\n[Step 1] Loading Reasoning Engine...")
        # Replace with the actual resource name of your deployed Reasoning Engine
        RESOURCE_NAME = "projects/941446881468/locations/us-central1/reasoningEngines/3052419101054992384"
        remote_agent = ReasoningEngine(RESOURCE_NAME)
        print("Success: Engine loaded.")
        
        # Sample data
        image_uri = "gs://saeed-demo-proj.firebasestorage.app/photos/euuK9uowLNd134saFlexiG3zu9b2/1773630269264.jpg"
        diseases = "Diabetic, High Blood Pressure"
        
        print(f"\n[Step 2] Sending Query for {image_uri}...")
        response = remote_agent.query(
            image_uri=image_uri,
            diseases=diseases,
            lab_results="A1C: 7.5%",
            medications="Metformin",
            activity_level=1.5,
            allergies="Peanuts"
        )
        
        print("\n--- TEST COMPLETE ---")
        print("Response Received:")
        import json
        print(json.dumps(response, indent=2))
        
    except Exception as e:
        print(f"\n!!! TEST FAILED !!!")
        print(f"Error Type: {type(e).__name__}")
        print(f"Message: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--agent", type=str, required=True)
    parser.add_argument("--project", type=str, default="saeed-demo-proj")
    parser.add_argument("--location", type=str, default="us-central1")
    
    args = parser.parse_args()
    test_agent(args.agent, args.project, args.location)
