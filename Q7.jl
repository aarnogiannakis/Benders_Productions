#********************************************************************************************************************
# Intro definitions
using JuMP
using HiGHS
#********************************************************************************************************************


#********************************************************************************************************************
# Parameters
P = 10 # Number of Products
M = 6 # Number of Machines
SCE = 5 # Number of Scenarios

# profit for each unit of product
Profit = [53, 67, 85, 82, 96, 59, 89, 89, 84, 58]
# Cost per unit of machine m
Cost = [329, 281, 221, 100, 327, 346]

# Min production requirement per product
MIN_PROD  = [5, 10, 10, 9, 7, 7, 6, 6, 5, 9]
# Number of minutes required per unit of product on machine m,
Tp_m = [ 6 7 6 5 8 6;
        5 10 7 10 9 6;
        6 10 5 6 10 6;
        5 9 10 8 9 10;
        8 7 8 9 9 10;
        8 7 7 5 8 9;
        6 9 9 8 5 5;
        10 8 7 5 7 7;
        7 7 7 8 8 9;
        10 9 5 9 9 10]

MAX_MINUTES = 480 # Maximum number of minutes per day on each machine
MAX_MACHINES = 15 # Maximum number of Machines
MAX_DEMAND = [ 15 36 17 22 22 17 94 27 30 38;
                        17 40 35 39 12 29 30 7 16 28;
                        31 40 34 10 9 26 64 19 25 14;
                        9 22 19 18 33 34 21 30 25 26;
                        26 21 40 10 32 10 86 24 10 25]
MAX_DEMAND = transpose(MAX_DEMAND)
π = 1 / SCE # Fixed number instead of a vector since its a equiprobable. In the assignment it is written as pi[s], but for simplicity I used a single value
#********************************************************************************************************************

#********************************************************************************************************************
# Model Initialization

"""My first-stage decision (here and now) is to determine how many machines I will operate for each type of machine.
    My second-stage decision (recourse) involves deciding how many units of each product to produce for each scenario,
    given the demand scenario after the uncertainty has been revealed"""

model = Model(HiGHS.Optimizer)

# First stage variables: Number of each machine type
@variable(model, x[m=1:M] >= 0, Int)
# Second stage variables: Production of each product on each machine in each scenario
@variable(model, y[p=1:P, sce=1:SCE] >= 0)


# Objective: Maximize expected profit
@objective(model, Max, -sum(Cost[m] * x[m] for m in 1:M) + sum(π *sum(Profit[p] * y[p,sce] for p in 1:P) for sce in 1:SCE) )

# Constraint for the total number of all machines not exceeding the factory limit
@constraint(model, sum(x[m] for m in 1:M) <= MAX_MACHINES)
# Constraint for the total production time per machine per scenario not exceeding available machine minutes
@constraint(model, [m=1:M, sce=1:SCE], sum(Tp_m[p,m] * y[p,sce] for p in 1:P) <= MAX_MINUTES * x[m])
# Constraint for minimum production requirements per product in each scenario
@constraint(model, [p=1:P, sce=1:SCE], y[p, sce] >= MIN_PROD[p])
# New --> Constraint for production not exceeding the demand for each product in each scenario
@constraint(model, [p=1:P, sce=1:SCE], y[p,sce] <= MAX_DEMAND[p,sce])
#********************************************************************************************************************


#********************************************************************************************************************
# Solve the model
optimize!(model)
#********************************************************************************************************************

#********************************************************************************************************************
# # Output results
println("-------------------------------------------------------------")
println("Optimal number of each machine type to buy:")
println([value(x[m]) for m in 1:M])

println("Optimal production plan per scenario and product:")
for sce in 1:SCE  # Scenario is the primary loop
    println("Scenario $(sce):")
    for p in 1:P  # Product is nested within scenario
        if value(y[p,sce]) > 0
            println("   Product $(p)", value(y[p,sce]))
        end
    end
end
println("-------------------------------------------------------------")
#********************************************************************************************************************


#********************************************************************************************************************
println("Successfull end of $(PROGRAM_FILE)")
#********************************************************************************************************************