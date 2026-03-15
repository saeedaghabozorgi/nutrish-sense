import vertexai
from vertexai.generative_models import GenerativeModel, Part

class ImageAnalyzerAgent:
    """An agent that analyzes an image and describes what is in it."""

    def __init__(self, project_id: str, location: str = "us-central1"):
        """Initialize the agent with project details."""
        vertexai.init(project=project_id, location=location)
        # Use gemini-2.5-flash as it is fast and supports multimodal input
        self.model = GenerativeModel("gemini-2.5-flash")

    def query(self, gcs_uri: str, prompt: str = "Describe what is in this image in detail.") -> str:
        """
        Analyzes an image stored in Google Cloud Storage.
        
        Args:
            gcs_uri: The Cloud Storage URI of the image (e.g., gs://bucket/path.jpg)
            prompt: The question or instruction for the model.
            
        Returns:
            The text response from the Gemini model.
        """
        try:
            # Load the image from the Cloud Storage URI
            image_part = Part.from_uri(gcs_uri, mime_type="image/jpeg")
            
            # Generate the response
            response = self.model.generate_content([image_part, prompt])
            
            return response.text
        except Exception as e:
            return f"Error analyzing image: {str(e)}"

    def set_up(self):
        """Standard Reasoning Engine setup method."""
        pass
