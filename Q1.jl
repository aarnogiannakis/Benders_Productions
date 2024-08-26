#********************************************************************************************************************
# Intro definitions
using JuMP
using Gurobi
#********************************************************************************************************************


#********************************************************************************************************************
# Parameters
P = 10 # Number of Products
M = 6 # Number of Machines
SCE = 5 # Number of Scenarios
MAX_MINUTES = 480 # Maximum number of minutes per day on each machine
MAX_MACHINES = 15 # Maximum number of Machines
Profit = [53, 67, 85, 82, 96, 59, 89, 89, 84, 58] # profit for each unit of product
Cost = [329, 281, 221, 100, 327, 346] # Cost per unit of machine m
Min_production  = [5, 10, 10, 9, 7, 7, 6, 6, 5, 9] # Min production requirement per product
# Number of minutes required per unit of product on machine m,
Time = [ 6 7 6 5 8 6;
    5 10 7 10 9 6;
    6 10 5 6 10 6;
    5 9 10 8 9 10;
    8 7 8 9 9 10;
    8 7 7 5 8 9;
    6 9 9 8 5 5;
    10 8 7 5 7 7;
    7 7 7 8 8 9;
    10 9 5 9 9 10]
#********************************************************************************************************************


#********************************************************************************************************************
# Model
Production_Model = Model(Gurobi.Optimizer)

@variable(Production_Model, x[1:M] >= 0, Int) # Number of machines of type m to use
@variable(Production_Model, y[1:P] >= 0) # Number of units of product p 

@objective(Production_Model, Max, sum(Profit[p] * y[p] for p in 1:P) - sum(Cost[m] * x[m] for m in 1:M))
# Constraint 1: Maximum number of minutes per day on each machine
@constraint(Production_Model, machine_util[m=1:M], sum(Time[p,m]*y[p] for p = 1:P) <= MAX_MINUTES * x[m])
# Constraint 2: Machine availability
@constraint(Production_Model, sum(x[m] for m = 1:M) <= MAX_MACHINES)
#********************************************************************************************************************


#********************************************************************************************************************
# Solve
optimize!(Production_Model)
#********************************************************************************************************************


#********************************************************************************************************************
# print model
println("-------------------------------------------------------------");
if termination_status(Production_Model) == MOI.OPTIMAL
    println("Optimal solution found:")
    println("Total Daily Profit: \$", objective_value(Production_Model))
    println("Machines to purchase:")
    for m in 1:M
        println("Machine Type ", m, ": ", value(x[m]), " unit(s)")
    end
    println("Production Plan:")
    for p in 1:P
        println("Product ", p, ": ", value(y[p]), " unit(s)")
    end
else
    println("No feasible solution found.")
end
println("-------------------------------------------------------------");
#********************************************************************************************************************

# #********************************************************************************************************************
println("Successfull end of $(PROGRAM_FILE)")
#********************************************************************************************************************