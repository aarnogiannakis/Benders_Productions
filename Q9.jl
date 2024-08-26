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
# equiprobable distribution
π = 1 / SCE
#********************************************************************************************************************


#********************************************************************************************************************
# MODEL
MP=Model(HiGHS.Optimizer)
set_silent(MP)

# Variables - single cut subproblem
@variable(MP, 100000 >= q >= -100000) # set bounds to q
@variable(MP, x[m=1:M]>=0, Int)

@objective(MP, Max, -sum(Cost[m]*x[m] for m=1:M) + q)

@constraint(MP, sum(x[m] for m =1:M) <= MAX_MACHINES)

function solve_master(alphabar, betabar, gammabar, opt_cut::Bool)
    if opt_cut
        # add an optimality cut
        @constraint(MP,sum(alphabar[m,sce]*MAX_MINUTES*x[m] for m=1:M, sce=1:SCE)
                        -sum(betabar[p,sce]*MIN_PROD[p] for p=1:P, sce=1:SCE)
                        + sum(gammabar[p,sce]*MAX_DEMAND[p,sce] for p=1:P, sce=1:SCE) >= q)
    else
        # add a feasibility cut
        @constraint(MP,sum(alphabar[m,sce]*MAX_MINUTES*x[m] for m=1:M, sce=1:SCE)
                        -sum(betabar[p,sce]*MIN_PROD[p] for p=1:P, sce=1:SCE)
                        + sum(gammabar[p,sce]*MAX_DEMAND[p,sce] for p=1:P, sce=1:SCE) >= 0)
    end
    optimize!(MP)
    (termination_status(MP) == MOI.OPTIMAL || error("Master problem not solved to optimality"))
    return objective_value(MP)
end
#********************************************************************************************************************


#********************************************************************************************************************
# Sub problem
function solve_subproblem(xbar)
    SP=Model(HiGHS.Optimizer)
    set_silent(SP)

    @variable(SP, alpha[m=1:M, sce=1:SCE] >=0)
    @variable(SP, beta[p=1:P, sce=1:SCE] >= 0)
    @variable(SP, gamma[p=1:P, sce=1:SCE ] >= 0)

    @objective(SP, Min, sum(alpha[m,sce]*MAX_MINUTES*xbar[m] for m=1:M, sce=1:SCE)
                            -sum(beta[p,sce]*MIN_PROD[p] for p=1:P, sce=1:SCE)
                            + sum(gamma[p,sce]*MAX_DEMAND[p,sce] for p=1:P, sce=1:SCE))

    @constraint(SP, y_produced[p=1:P, sce=1:SCE], sum(Tp_m[p,m]*alpha[m,sce] for m=1:M) - beta[p,sce] +gamma[p,sce] >= Profit[p]*π)

    optimize!(SP)

    if termination_status(SP) == MOI.OPTIMAL
        return (true, objective_value(SP), value.(alpha), value.(beta), value.(gamma), dual.(y_produced))
    end
    if termination_status(SP) == MOI.INFEASIBLE_OR_UNBOUNDED || termination_status(SP) == MOI.DUAL_INFEASIBLE
        return (false, objective_value(SP), value.(alpha), value.(beta), value.(gamma), dual.(y_produced))
    end
end
#********************************************************************************************************************


#********************************************************************************************************************
# Ray problem
function solve_ray(xbar)
    ray=Model(HiGHS.Optimizer)
    set_silent(ray)

    # Variables
    @variable(ray, alpha[m=1:M, sce=1:SCE] >= 0)
    @variable(ray, beta[p=1:P, sce=1:SCE]  >= 0)
    @variable(ray, gamma[p=1:P, sce=1:SCE] >= 0)

    # Objective
    @objective(ray, Min, -1 )

    # Constraints 1 
    @constraint(ray,  sum(alpha[m,sce]*MAX_MINUTES*xbar[m] for m=1:M, sce=1:SCE)
                        -sum(beta[p,sce]*MIN_PROD[p] for p=1:P, sce=1:SCE)
                        + sum(gamma[p,sce]*MAX_DEMAND[p,sce] for p=1:P, sce=1:SCE) == -1)

    # Constraints 2
    @constraint(ray, [p=1:P, sce=1:SCE], sum(Tp_m[p,m]*alpha[m,sce] for m=1:M)
                                                    - beta[p,sce] + gamma[p,sce] >= 0)

    optimize!(ray)
    if termination_status(ray) == MOI.OPTIMAL
        return (objective_value(ray), value.(alpha), value.(beta), value.(gamma))
    else
        error("The solver did not find an optimal solution.")
    end
end
#********************************************************************************************************************


#********************************************************************************************************************
# main code
println("------------------------------------------------------------------------------------------")
let
    UB=Inf
    LB=-Inf
    Delta= 0
    timestart = time() 
    
    #initial solution - set all shipment values zero
    x_bar= ones(Int, M)

    it=1
    while (UB-LB>Delta)
        (sub_prob_solution, sub_obj, alphabar,betabar, gammabar,y_produced) = solve_subproblem(x_bar)
        if sub_prob_solution
            mas_component = -sum(Cost[m]*value(x[m]) for m=1:M)
            LB = max(LB, sub_obj + mas_component)
        else
            (ray_obj, alphabar, betabar, gammabar) = solve_ray(x_bar)
        end
        mas_obj=solve_master(alphabar, betabar,gammabar, sub_prob_solution)
        x_bar = value.(x)
        UB = mas_obj
        if sub_prob_solution
            # println("SUB It: $(it) UB: $(UB) LB: $(LB) Sub: $(sub_obj)")
            @printf("SUB It: %d UB: %.2f LB: %.2f Sub: %.2f\n", it, UB, LB, sub_obj)
        else
            # println("RAY It: $(it) UB: $(UB) LB: $(LB) Sub: $(ray_obj)")
            @printf("RAY It: %d UB: %.2f LB: %.2f Sub: %.2f\n", it, UB, LB, ray_obj)
        end
        it+=1

        print("Buy x amount of Machine (1-->6) : ")
        for x in x_bar
            @printf("%d ", x)
        end
        println()

        print("Quantity of produced products (1-->10) : ")
        count = 0
        for y in y_produced
            @printf("%.2f ", y)
            count += 1
            if count % 10 == 0
                println()
                print("                                  : ")  # Adjust indentation to align with the first line
            end
        end
        println() 
        println("------------------------------------------------------------------------------------------")
    end
    # timeend = time()  # get the end time
    # timetaken = timeend - timestart  # calculate the time taken

    # println("Time taken: $timetaken seconds")
end
#********************************************************************************************************************


#********************************************************************************************************************
println("Successfull end of $(PROGRAM_FILE)")
#********************************************************************************************************************