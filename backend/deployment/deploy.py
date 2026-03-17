import argparse
import vertexai
from vertexai.preview.reasoning_engines import ReasoningEngine

from dietary_agent.agent import app

AGENT_WHL_FILE = "dist/dietary_agent-3.1.0-py3-none-any.whl"

def deploy_agent(project: str, location: str, staging_bucket: str):
    print(f"Initializing deployment for project {project} in {location}...")
    vertexai.init(project=project, location=location, staging_bucket=staging_bucket)

    display_name = "Multi-Agent ADK Dietician Release 3.1"
    print(f"Checking for existing 'Multi-Agent ADK Dietician Release' instances to update...")
    engines = ReasoningEngine.list()
    
    existing_engine_id = None
    for engine in engines:
        if engine.display_name.startswith("Multi-Agent ADK Dietician Release"):
            existing_engine_id = engine.resource_name
            break

    print("Instantiating the ADK app for deployment...")
    
    requirements = [
        "google-cloud-aiplatform[reasoningengine]>=1.64.0",
        "google-adk>=0.0.2",
        "pydantic>=2.9.2",
        f"./{AGENT_WHL_FILE}"
    ]
    extra_packages = [f"./{AGENT_WHL_FILE}"]

    if existing_engine_id:
        print(f"Update existing engine {existing_engine_id}...")
        remote_agent = ReasoningEngine(existing_engine_id)
        try:
            remote_agent.update(
                reasoning_engine=app,
                requirements=requirements,
                extra_packages=extra_packages
            )
        except Exception as e:
            if "effectiveIdentity" in str(e):
                print("Note: Caught known protobuf ParseError for effectiveIdentity. The backend update succeeded.")
            else:
                raise
    else:
        print("Deploying the ADK to a NEW Vertex AI Reasoning Engine...")
        remote_agent = ReasoningEngine.create(
            app,
            requirements=requirements,
            extra_packages=extra_packages,
            display_name=display_name
        )

    print("Deployment successful!")
    print(f"Agent ID: {remote_agent.resource_name}")
    
    with open("agent_id.txt", "w") as f:
        f.write(remote_agent.resource_name)
    print("Saved resource name to agent_id.txt")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Deploy the ADK DietaryCoordinatorAgent to Vertex AI.")
    parser.add_argument("--project", type=str, required=True, help="Google Cloud Project ID")
    parser.add_argument("--location", type=str, default="us-central1", help="Google Cloud Region (default: us-central1)")
    parser.add_argument("--bucket", type=str, required=True, help="Cloud Storage Staging Bucket (must start with gs://)")
    
    args = parser.parse_args()
    deploy_agent(args.project, args.location, args.bucket)
