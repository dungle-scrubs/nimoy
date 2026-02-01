import Foundation

/// Templates and examples for LLM to understand Nimoy syntax
struct NimoyTemplates {
    
    static let syntaxGuide = """
    # Nimoy Calculator Syntax Guide
    
    ## Variables
    - Assign with `=`: `rent = 1500`
    - Use variables in expressions: `rent + utilities`
    - Variable names: lowercase, underscores allowed: `monthly_total`
    
    ## Numbers & Currencies
    - Plain numbers: `100`, `3.14`, `1000`
    - USD: `$100` or `100 USD`
    - Thai Baht: `700 THB`
    - Euro: `50 EUR`
    - Other: `100 GBP`, `100 JPY`, etc.
    
    ## Currency Conversion
    - Convert inline: `700 THB in USD` → converts to USD
    - Convert result: `phone = 700 THB in USD`
    
    ## Summing Lines
    - `sum` keyword sums all numeric results above (until previous sum or heading)
    - Use after a group of related items
    
    ## Comments & Sections
    - Headings: `# Section` or `## Subsection`
    - Comments: `// this is ignored`
    - Blank lines are allowed
    
    ## Percentages
    - `15% of 200` → 30
    - `tax = 7% of subtotal`
    - `X as a % of Y` → percentage
    
    ## Math Functions
    - `sqrt(16)` or `square root of 16`
    - `sin(45°)`, `cos(60°)`, `tan(30°)`
    - `log(100)`, `ln(10)`
    - `abs(-5)`, `round(3.7)`, `floor(3.9)`, `ceil(3.1)`
    
    ## Unit Conversions
    - Length: `5km in miles`, `100cm in inches`
    - Weight: `10kg in lbs`
    - Temperature: `100°F in °C`
    - Digital: `1024mb in gb`
    - CSS: `16px in em`, `1rem in px`
    """
    
    static let exampleBudget = """
    # Monthly Budget
    
    ## Housing
    rent = $1500
    utilities = $150
    internet = $60
    housing_total = sum
    
    ## Food
    groceries = $400
    restaurants = $200
    coffee = $50
    food_total = sum
    
    ## Transport
    gas = $150
    insurance = $100
    transport_total = sum
    
    ## Total
    housing_total
    food_total
    transport_total
    monthly_total = sum
    """
    
    static let exampleMultiCurrency = """
    # Travel Budget (Thailand)
    
    ## Accommodation
    hotel = 3500 THB in USD
    airbnb = 2000 THB in USD
    accommodation_total = sum
    
    ## Food
    street_food = 500 THB in USD
    restaurants = 1500 THB in USD
    food_total = sum
    
    ## Activities
    temple_tours = 800 THB in USD
    massage = 600 THB in USD
    activities_total = sum
    
    ## Daily Total
    accommodation_total
    food_total
    activities_total
    daily_total = sum
    """
    
    static let exampleFreelance = """
    # Freelance Invoice
    
    ## Development Work
    frontend = 40 * 75
    backend = 25 * 85
    devops = 10 * 100
    dev_subtotal = sum
    
    ## Design Work
    ui_design = 15 * 65
    revisions = 5 * 50
    design_subtotal = sum
    
    ## Expenses
    software = $50
    hosting = $25
    expenses_subtotal = sum
    
    ## Invoice Total
    dev_subtotal
    design_subtotal
    expenses_subtotal
    subtotal = sum
    tax = 10% of subtotal
    total = subtotal + tax
    """
    
    static let exampleComparison = """
    # Phone Plan Comparison
    
    ## Plan A
    plan_a_monthly = $45
    plan_a_yearly = plan_a_monthly * 12
    
    ## Plan B
    plan_b_monthly = $55
    plan_b_yearly = plan_b_monthly * 12
    
    ## Savings
    yearly_difference = plan_b_yearly - plan_a_yearly
    savings_percent = yearly_difference as a % of plan_b_yearly
    """
    
    static let exampleUnitConversions = """
    # Recipe Scaling (serves 8 → 12)
    
    scale = 12 / 8
    
    ## Ingredients
    flour = 2 * scale
    sugar = 1.5 * scale
    butter = 200 * scale
    
    ## Conversions
    flour_oz = flour * 4.4
    butter_tbsp = butter / 14
    
    // Temperature
    oven_f = 350
    oven_c = oven_f in °C
    """
    
    /// Combined prompt context for generation
    static var generationContext: String {
        """
        You generate Nimoy calculator documents. Nimoy is a natural language calculator.
        
        \(syntaxGuide)
        
        ## Example 1: Monthly Budget
        ```
        \(exampleBudget)
        ```
        
        ## Example 2: Multi-Currency Travel Budget
        ```
        \(exampleMultiCurrency)
        ```
        
        ## Example 3: Freelance Invoice with Tax
        ```
        \(exampleFreelance)
        ```
        
        ## Example 4: Comparison with Percentages
        ```
        \(exampleComparison)
        ```
        
        RULES:
        1. Output ONLY the Nimoy document, no explanations
        2. Use clear section headings with #
        3. Use descriptive variable names with underscores
        4. Group related items, then use `sum`
        5. Convert currencies when user specifies target currency
        6. Reference subtotals before final sum
        """
    }
}
