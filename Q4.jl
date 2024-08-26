#********************************************************************************************************************
# Intro definitions
using JuMP
using Printf
using HiGHS
#********************************************************************************************************************


#********************************************************************************************************************
# Parameters
P = 10 # Number of Products
M = 6 # Number of Machines
SCE = 5 # Number of Scenarios
MAX_MINUTES = 480 # Maximum number of minutes per day on each machine
MAX_MACHINES = 15 # Maximum number of Machines

# profit for each unit of product
Profit = [53, 67, 85, 82, 96, 59, 89, 89, 84, 58]
# Cost per unit of machine m
Cost = [329, 281, 221, 100, 327, 346]

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
# Master problem
mas = Model(HiGHS.Optimizer)
set_silent(mas)

# Variables
@variable(mas, q ) # free variable
@variable(mas, x[1:M] >= 0, Int) # Number of machines of type m to use
@objective(mas, Max, -sum(Cost[m]*x[m] for m in 1:M) + q)

# Define the constraint outside of the master function to only call it once
@constraint(mas, sum(x[m] for m = 1:M) <= MAX_MACHINES)

function solve_master(alphabar)
    # Add Constraints
    @constraint(mas, sum(alphabar[m]*MAX_MINUTES*x[m] for m in 1:M) >= q)
    # Maximum number of machine
    optimize!(mas)
    return objective_value(mas)
end
#********************************************************************************************************************

#********************************************************************************************************************
# This function solves the subproblem given a set of machines x_bar
function solve_sub(x_bar)
    sub=Model(HiGHS.Optimizer)
    set_silent(sub)

    @variable(sub, alpha[1:M] >= 0) # The dual variable
    @objective(sub, Min, sum(alpha[m]*MAX_MINUTES*x_bar[m] for m in 1:M)) 

    @constraint(sub, y_values[p=1:P], sum(Time[p,m]*alpha[m] for m in 1:M) >= Profit[p] )

    optimize!(sub)
    status = termination_status(sub) # Check the status of the optimization

    if status == MOI.OPTIMAL
        # Optimization was successful, extract values
        alpha_vals = value.(alpha)
        obj_val = objective_value(sub)
        y_vals = dual.(y_values)  # Capture dual values 
    else
        error("Sub problem not solved to optimality")
    end
    return (obj_val, alpha_vals, y_vals)
end    
#********************************************************************************************************************



#********************************************************************************************************************
# main code
println("-------------------------------------------------------------")
let
    UB=Inf
    LB=-Inf
    Delta=0
    x_bar= ones(Int, M)  # Assume 1 of each machine
    it=1
    while (UB-LB>Delta)
        # Call the subproblem to get the value of the dual variable and the objective for the given set of machines
        (sub_obj, alphabar, y_vals) = solve_sub(x_bar)
        # Update the lower bound
        LB = max(LB, sub_obj -sum(Cost[m]*x_bar[m] for m in 1:M) )
        # Call the master problem to calculate new set set of machines
        mas_obj=solve_master(alphabar)
        x_bar=value.(x)
        # Update the upper bound
        UB=mas_obj
        println("It: $(it) UB: $(UB) LB: $(LB)  Sub: $(sub_obj)")
        it+=1

        print("Buy x amount of Machines (1-->6) : ")
        for x in x_bar
            @printf("%d ", x)
        end

        println()

        print("Quantity of produced products (1-->10) : ")
        for y in y_vals
            @printf("%.2f ", y)
        end

        println() 
        println("-------------------------------------------------------------");
    end
end
#********************************************************************************************************************


#********************************************************************************************************************
println("Successfull end of $(PROGRAM_FILE)")
#********************************************************************************************************************