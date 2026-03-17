from google.adk import Agent

clinical_agent = Agent(
    name="clinical_agent",
    model="gemini-3-flash-preview",
    description="Tool to evaluate ALL of the user's medical conditions, allergies, and medications against the ingredients extracted by the vision agent.",
    instruction="""
    Act as a highly specialized medical dietician.
    You will be provided with:
    1. The ingredients and portion size of a food item.
    2. The patient's full medical context (diseases, allergies, medications, lab results).
    
    Evaluate the impact of the food on EVERY condition listed.
    For each condition, explicitly state if the food is 'Green' (Safe), 'Yellow' (Caution), or 'Red' (Warning/Avoid) and provide the clinical reasoning.
    Provide a comprehensive breakdown of your reasoning for each disease.
    """,
    output_key="clinical_assessment"
)
