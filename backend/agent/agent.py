import vertexai
from vertexai.generative_models import GenerativeModel, Part

class ImageAnalyzerAgent:
    """An agent that analyzes an image and describes what is in it."""

    def __init__(self, project_id: str, location: str = "us-central1"):
        """Initialize the agent with project details."""
        vertexai.init(project=project_id, location=location)
        # Use gemini-2.5-flash as it is fast and supports multimodal input
        self.model = GenerativeModel("gemini-2.5-flash")

    def query(self, gcs_uri: str, disease: str) -> str:
        """
        Analyzes an image stored in Google Cloud Storage for dietary guidelines.
        
        Args:
            gcs_uri: The Cloud Storage URI of the image (e.g., gs://bucket/path.jpg)
            disease: The medical condition selected by the user.
            
        Returns:
            The text response from the Gemini model in JSON format.
        """
        try:
            # Load the image from the Cloud Storage URI
            image_part = Part.from_uri(gcs_uri, mime_type="image/jpeg")
            
            prompt = f"""
            You are an expert medical dietician. I am a patient with the following condition: {disease}.
            Please analyze the food or restaurant menu in the attached image to determine if it is suitable for my condition.

            Provide your response STRICTLY as a valid JSON object with the following three keys:
            1. "color": A string that is exactly "Green" (Safe to eat), "Yellow" (Eat with caution/moderation), or "Red" (Do not eat).
            2. "assessment": A detailed string explaining why this food is rated this way based on medical dietary guidelines for {disease}.
            3. "alternatives": A string suggesting healthier alternatives if applicable. Wait, if it is Green, just say "This is a great choice!".

            Do not wrap the JSON output in markdown formatting (like ```json), just return the raw JSON string starting with {{ and ending with }}.
            """
            
            # Generate the response
            response = self.model.generate_content([image_part, prompt])
            
            return response.text
        except Exception as e:
            return f"{{\"color\": \"Red\", \"assessment\": \"Error analyzing image: {str(e)}\", \"alternatives\": \"N/A\"}}"

    def set_up(self):
        """Standard Reasoning Engine setup method."""
        pass
