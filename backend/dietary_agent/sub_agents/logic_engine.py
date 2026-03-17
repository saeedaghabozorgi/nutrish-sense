from google.adk import Agent

logic_engine = Agent(
    name="logic_engine",
    model="gemini-3-flash-preview",
    description="Tool to resolve conflicting disease guidelines and format the final JSON output.",
    instruction="""
    Act as the Chief Dietician and Health Coach. 
    Review the individual disease assessments evaluated by the prior agents.
    1. Determine the SAFEST OVERALL color across ALL conditions (Green, Yellow, or Red).
    2. Extract a short 2-4 word name for the food.
    3. Suggest healthy alternatives for the user based on the ingredients and conditions.
    """,
    output_key="logic_output"
)
