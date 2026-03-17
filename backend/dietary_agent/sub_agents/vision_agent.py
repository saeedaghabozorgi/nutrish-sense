from google.adk import Agent

# We define the specialized agent configuration
vision_agent = Agent(
    name="vision_agent",
    model="gemini-3-flash-preview",
    description="Tool to extract a strict deconstructed list of the food ingredients and portion size from the uploaded image.",
    instruction="""
    Act as a Vision Specialist. Analyze the image uploaded by the patient. 
    Identify the precise food, its main ingredients, and estimate the portion size.
    Output ONLY the deconstructed ingredient list and portion. Do not add any conversational filler.
    """,
    output_key="vision_ingredients"
)
