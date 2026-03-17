import os
import vertexai
from google.adk.agents import LlmAgent
from vertexai.agent_engines import AdkApp
from dotenv import load_dotenv

from .sub_agents.vision_agent import vision_agent
from .sub_agents.clinical_agent import clinical_agent

# Load dot env variables from the nearest .env file
load_dotenv()

# Setup
os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "true"
vertexai.init(
    project=os.environ.get("GCP_PROJECT_ID", "saeed-demo-proj"), 
    location=os.environ.get("GCP_LOCATION", "us-central1")
)

prompt_path = os.path.join(os.path.dirname(__file__), "prompt.txt")
with open(prompt_path, "r") as f:
    master_instruction = f.read()

agent = LlmAgent(
    name="chief_agent",
    model="gemini-3-flash-preview",
    instruction=master_instruction,
    tools=[vision_agent, clinical_agent]
)

app = AdkApp(agent=agent)