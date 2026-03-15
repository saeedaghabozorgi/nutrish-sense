import argparse
import vertexai
from vertexai.preview.reasoning_engines import ReasoningEngine

# Import our custom agent class
from agent import ImageAnalyzerAgent

def deploy_agent(project_id: str, location: str, gcs_staging_bucket: str):
    print(f"Initializing deployment for project {project_id} in {location}...")
    vertexai.init(
        project=project_id, 
        location=location,
        staging_bucket=gcs_staging_bucket
    )

    print("Instantiating the agent...")
    agent = ImageAnalyzerAgent(project_id=project_id, location=location)

    print("Deploying to Vertex AI Reasoning Engine...")
    remote_agent = ReasoningEngine.create(
        agent,
        requirements=[
            "google-cloud-aiplatform",
        ],
        extra_packages=["agent.py"],
        display_name="Flutter Image Analysis Agent"
    )

    print("Deployment successful!")
    print(f"Agent ID: {remote_agent.resource_name}")
    
    # Save the resource name to a file so we can use it in Cloud Functions
    with open("agent_id.txt", "w") as f:
        f.write(remote_agent.resource_name)
    print("Saved resource name to agent_id.txt")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Deploy the Image Analyzer Agent")
    parser.add_argument("--project", required=True, help="Google Cloud Project ID")
    parser.add_argument("--location", default="us-central1", help="Google Cloud Region")
    parser.add_argument("--bucket", required=True, help="GCS Staging Bucket (gs://...)")
    
    args = parser.parse_args()
    deploy_agent(args.project, args.location, args.bucket)
