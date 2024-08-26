#********************************************************************************************************************
# Intro definitions
using JuMP
using HiGHS
using Printf
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

@variable(MP, 100000 >= q >= -100000) 
@variable(MP, x[m=1:M]>=0, Int)

@objective(MP, Max, -sum(Cost[m]*x[m] for m=1:M) + q)
@constraint(MP, sum(x[m] for m =1:M) <= MAX_MACHINES)

# solve master problem
function solve_master(alphabar, betabar, gammabar, opt_cut)
    if all(opt_cut)
        @constraint(MP,sum(alphabar[m,sce]*MAX_MINUTES*x[m] for m=1:M, sce=1:SCE)
                        -sum(betabar[p,sce]*MIN_PROD[p] for p=1:P, sce=1:SCE)
                        + sum(gammabar[p,sce]*MAX_DEMAND[p,sce] for p=1:P, sce=1:SCE) >= q)
    else
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
# Changed --> Now receive scenario s
function solve_subproblem(xbar,s)
    SP=Model(HiGHS.Optimizer)
    set_silent(SP)

    @variable(SP, alpha[m=1:M] >=0)
    @variable(SP, beta[p=1:P] >= 0)
    @variable(SP, gamma[p=1:P] >= 0)

    @objective(SP, Min, sum(alpha[m]*MAX_MINUTES*xbar[m] for m=1:M)
                            -sum(beta[p]*MIN_PROD[p] for p=1:P)
                            + sum(gamma[p]*MAX_DEMAND[p,s] for p=1:P))

    @constraint(SP, scenario_produced[p=1:P], sum(Tp_m[p,m]*alpha[m] for m=1:M) - beta[p] +gamma[p] >= Profit[p]*π)
    optimize!(SP)

    if termination_status(SP) == MOI.OPTIMAL
        return (true, objective_value(SP), value.(alpha), value.(beta), value.(gamma), dual.(scenario_produced))
    end
    if termination_status(SP) == MOI.INFEASIBLE_OR_UNBOUNDED || termination_status(SP) == MOI.DUAL_INFEASIBLE
        return (false, objective_value(SP), value.(alpha), value.(beta), value.(gamma), dual.(scenario_produced))
    end
end
#********************************************************************************************************************


#********************************************************************************************************************
# Changed Ray problem  --> Receive scenario s
function solve_ray(xbar, s) 
    ray=Model(HiGHS.Optimizer)
    set_silent(ray)

    # Variables
    @variable(ray, alpha[m=1:M] >= 0)
    @variable(ray, beta[p=1:P]  >= 0)
    @variable(ray, gamma[p=1:P] >= 0)

    # Objective
    @objective(ray, Min, -1 )

    # Constraints
    @constraint(ray,  sum(alpha[m]*MAX_MINUTES*xbar[m] for m=1:M)
                        -sum(beta[p]*MIN_PROD[p] for p=1:P)
                        + sum(gamma[p]*MAX_DEMAND[p,s] for p=1:P) == -1)

    @constraint(ray, [p=1:P], sum(Tp_m[p,m]*alpha[m] for m=1:M)
                                                    - beta[p] + gamma[p] >= 0)

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
println("-------------------------------------------------------------")
let
    UB=Inf
    LB=-Inf
    Delta= 1e-6
    sub_prob_solution = zeros(Bool, SCE)
    x_bar= ones(Int, M)
    
    #############################
    # We now need to store the values of the variables in each scenario
    sub_obj = zeros(Float64, SCE)
    ray_obj = zeros(Float64, SCE)
    alpha = zeros(M,SCE)  
    beta = zeros(P,SCE)  
    gamma = zeros(P,SCE)  
    duals = zeros(P,SCE)
    #############################

    timestart = time() 
    it=1
    while (UB-LB>Delta)
        # for each scenario call the subproblem with a different scenario
        for s=1:SCE
            (sub_prob_solution[s], sub_obj[s], alpha[:,s], beta[:,s], gamma[:,s], duals[:,s]) = solve_subproblem(x_bar,s)
        end
        
        # if all scenarios are feasible
        if all(sub_prob_solution)
            mas_component = -sum(Cost[m]*value(x[m]) for m=1:M)
            LB = max(LB, sum(sub_obj[s] for s=1:SCE) + mas_component)
        else
            # if not, then for each scenario call the ray problem, to create a feasibility cut
            for s=1:SCE
                (ray_obj[s], alpha[:,s], beta[:,s], gamma[:,s]) = solve_ray(x_bar, s)
            end
        end

        mas_obj=solve_master(alpha, beta,gamma, sub_prob_solution)
        x_bar = value.(x)
        UB = mas_obj

        if all(sub_prob_solution)
            println("SUB It: $(it) UB: $(UB) LB: $(LB) Sub: $(sub_obj)")
        else
            # if even one scenario is infeasible, then you used the ray problem
            println("RAY It: $(it) UB: $(UB) LB: $(LB) Sub: $(ray_obj)")
        end
        it+=1

        print("Buy x amount of Machine (1-->6) : ")
        for x in x_bar
            @printf("%d ", x)
        end
        println()

        print("Quantity of produced products (1-->10) : ")
        count = 0
        for y in duals
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
    timeend = time()  # get the end time
    timetaken = timeend - timestart  # calculate the time taken
    println("Time taken: $timetaken seconds")
end
println("-------------------------------------------------------------")
#********************************************************************************************************************


#********************************************************************************************************************
# # Output results
# println("Optimal number of each machine type to buy:")
# println([value(x[m]) for m in 1:M])
#********************************************************************************************************************



#********************************************************************************************************************
println("Successfull end of $(PROGRAM_FILE)")
#********************************************************************************************************************