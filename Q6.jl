#********************************************************************************************************************
# Intro definitions
using JuMP
using HiGHS
using Printf
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
# Min production requirement per product
Min_production  = [5, 10, 10, 9, 7, 7, 6, 6, 5, 9]

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
mas=Model(HiGHS.Optimizer)
set_silent(mas)

# Variables
@variable(mas, 100000 >= q >= -100000) # Give bounds to the variable to avoid problems with the Solver
@variable(mas, x[1:M] >=0, Int) # Number of machines of type m to use
@objective(mas, Max, -sum(Cost[m]*x[m] for m in 1:M) + q)

@constraint(mas, sum(x[m] for m =1:M) <= MAX_MACHINES)

function solve_master( alphabar, betabar, opt_cut::Bool )
    if opt_cut
        # Add an optimality cut
        @constraint(mas,sum(alphabar[m]*MAX_MINUTES*x[m] for m in 1:M) 
                        -sum(betabar[p]*Min_production[p] for p in 1:P) >= q)

    else
        # Add an feasibility cut
        @constraint(mas,sum(alphabar[m]*MAX_MINUTES*x[m] for m in 1:M) 
                        -sum(betabar[p]*Min_production[p] for p in 1:P) >= 0)
    end

    optimize!(mas)
    (termination_status(mas) == MOI.OPTIMAL || error("Master problem not solved to optimality"))
    return objective_value(mas)
end
#********************************************************************************************************************


#********************************************************************************************************************
# Sub problem
function solve_sub(x_bar)
    sub=Model(HiGHS.Optimizer)
    set_silent(sub)

    # One extra dual Variable in comparison with Q4 due to extra constraint
    @variable(sub, alpha[1:M] >= 0)
    @variable(sub, beta[1:P] >= 0)

    # Objective
    @objective(sub, Min,  sum(alpha[m]*MAX_MINUTES*x_bar[m] for m=1:M) 
                            -sum(beta[p]*Min_production[p] for p=1:P))

    # Constraints
    @constraint(sub, y_produced[p=1:P], sum(Time[p,m]*alpha[m] for m in 1:M) - beta[p] >= Profit[p])

    optimize!(sub)
    
    if termination_status(sub) == MOI.OPTIMAL
        return (true, objective_value(sub), value.(alpha), value.(beta), dual.(y_produced))
    elseif termination_status(sub) == DUAL_INFEASIBLE
        return (false, objective_value(sub), value.(alpha), value.(beta), dual.(y_produced))
    end
end
#********************************************************************************************************************


#********************************************************************************************************************
# Ray problem
function solve_ray(x_bar)
    ray=Model(HiGHS.Optimizer)
    set_silent(ray)
    
    # Variables
    @variable(ray, alpha[1:M] >= 0)
    @variable(ray, beta[1:P] >= 0)

    # Objective
    @objective(ray, Min, -1 )

    # Constraints
    @constraint(ray, sum(alpha[m]*MAX_MINUTES*x_bar[m] for m=1:M)
                        - sum(beta[p]*Min_production[p] for p=1:P) == -1)
    # Constraints
    @constraint(ray, [p=1:P], sum(Time[p,m]*alpha[m] for m=1:M) - beta[p] >= 0)
    
    optimize!(ray)
    return (objective_value(ray), value.(alpha), value.(beta))
end
#********************************************************************************************************************


#********************************************************************************************************************
# main code
println("-------------------------------------------------------------")
let
    UB=Inf
    LB=-Inf
    Delta=0
    x_bar = ones(Int, M)
    it=1
    while (UB-LB>Delta) 
        println("-------------------------------------------------------------")

        (sub_prob_solution, sub_obj, alphabar, betabar, y_produced) = solve_sub(x_bar)
        if sub_prob_solution
            LB = max(LB, sub_obj - sum(Cost[m]*value(x[m]) for m in 1:M))
        else
            # not feasible result so create a feasibility cut 
            (ray_obj, alphabar, betabar) = solve_ray(x_bar)
        end
        # update the  machines purchase
        mas_obj = solve_master(alphabar, betabar, sub_prob_solution)
        x_bar = value.(x)
        # update the upper bound
        UB=mas_obj
        if sub_prob_solution
            # you used the subproblem
            @printf("SUB It: %d UB: %.2f LB: %.2f Sub: %.2f\n", it, UB, LB, sub_obj)
            # println("SUB It: $(it) UB: $(UB) LB: $(LB) Sub: $(sub_obj)")
        else
            # you used the ray
            @printf("RAY It: %d UB: %.2f LB: %.2f Sub: %.2f\n", it, UB, LB, ray_obj)
            # println("RAY It: $(it) UB: $(UB) LB: $(LB) Sub: $(ray_obj)")
        end
        it+=1

        print("Buy x amount of Machine (1-->6) : ")
        for x in x_bar
            @printf("%d ", x)
        end
        println()
        print("Quantity of produced products (1-->10) : ")
        for y in y_produced
            @printf("%.2f ", y)
        end

        println() 
        println("-------------------------------------------------------------")

    end
end
#********************************************************************************************************************


#********************************************************************************************************************
println("Successfull end of $(PROGRAM_FILE)")
#********************************************************************************************************************