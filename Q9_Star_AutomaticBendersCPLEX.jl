#********************************************************************************************************************
# Intro definitions
using JuMP
using CPLEX
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
# equiprobable distribution
π = 1 / SCE
#********************************************************************************************************************


#*********************** Automatic Benders using CPLEX *********************************************************************************************
# # This part of the code uses the CPLEX optimizer to automatically solve the problem to check our results
model=Model(CPLEX.Optimizer)

set_optimizer_attribute(model, "CPXPARAM_Preprocessing_Presolve", 0)
set_optimizer_attribute(model, "CPXPARAM_Benders_Strategy", 3)
set_optimizer_attribute(model, "CPX_PARAM_CUTPASS", -1) 

@variable(model, x[m=1:M] >= 0, Int)
@variable(model, y[p=1:P, sce=1:SCE] >= 0)
@objective(model, Max, -sum(Cost[m] * x[m] for m in 1:M) + sum(π *sum(Profit[p] * y[p,sce] for p in 1:P) for sce in 1:SCE) )

@constraint(model, sum(x[m] for m in 1:M) <= MAX_MACHINES)
@constraint(model, [m=1:M, sce=1:SCE], sum(Tp_m[p,m] * y[p,sce] for p in 1:P) <= MAX_MINUTES * x[m])
@constraint(model, [p=1:P, sce=1:SCE], y[p, sce] >= MIN_PROD[p])
@constraint(model, [p=1:P, sce=1:SCE], y[p,sce] <= MAX_DEMAND[p,sce])

@time begin
        optimize!(model)
end
#********************************************************************************************************************

#********************************************************************************************************************
# # Output results
println("-------------------------------------------------------------")
println("Optimal number of each machine type to buy:")
println([value(x[m]) for m in 1:M])
println("-------------------------------------------------------------")
println("Optimal number of products produced per scenario:")
println([value(y[p,s]) for p in 1:P, s in 1:SCE])
println("-------------------------------------------------------------")
#********************************************************************************************************************


#********************************************************************************************************************
println("Successfull end of $(PROGRAM_FILE)")
#********************************************************************************************************************