import os
import vertexai
from google.adk.agents import LlmAgent
from vertexai.agent_engines import AdkApp

# Setup
os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "true"
vertexai.init(project="saeed-demo-proj", location="us-central1")

agent = LlmAgent(
    name="chief_agent",
    model="gemini-2.5-flash",
    instruction="""
    Act as a medical dietician. 
    Analyze the food image provided and the patient's context (diseases, lab results, medications, allergies).
    Provide a detailed assessment of how this food affects the patient's conditions, and suggest healthy alternatives.
    Please format your response clearly. You should provide the assesment per user's desease, and overall assesment. Feel free to use lists or paragraphs.
    You should provide the response in JSON format with the following structure:
    {
        "food_name": "Name of the food",
        "food_category": "Category of the food",
        "overall_color": "Color associated to degree of the food being healthy or unhealthy considering users diseases. Green for healthy, Yellow for moderate, Red for unhealthy.",
        "overall_rating": "Overall rating of the food",
        "overall_assessment": "Overall assessment of the food",
        "disease_assessments": {
            "disease_name": "Assessment of the food for the disease",
            "disease_name": "Assessment of the food for the disease"
        },
        "healthy_alternatives": [
            "Healthy alternative 1",
            "Healthy alternative 2"
        ]
    }
    """
)

app = AdkApp(agent=agent)