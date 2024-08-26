# Benders_Productions

Benders Production Optimization Project
Overview
This repository contains the implementation of a project focused on optimizing the production process of Benders Production, a chemical production company. The goal is to maximize the daily profit from producing various chemical products using a limited number of machines. The project involves formulating and solving a series of mathematical optimization problems using Mixed-Integer Programming (MIP) and Benders Decomposition techniques. The project is implemented in Julia.

Project Structure
The project is divided into several questions, each addressing different aspects of the optimization process. Below is a brief description of each question:

Question 1: Mixed-Integer Programming (MIP) Formulation
Objective: Formulate a MIP model to maximize the daily profit by determining the optimal number of machines to purchase and the amount of each product to produce. The model considers machine costs, production times, and profit margins for each product.
Code: Implemented in Q1.jl.
Question 2: Benders Subproblem Formulation
Objective: Formulate the Benders subproblem based on the MIP model developed in Question 1.
Code: Implementation of the formulation is included in the documentation.
Question 3: Benders Master Problem Formulation
Objective: Formulate the Benders master problem that controls the selection of machines, which is used in the iterative Benders Decomposition algorithm.
Code: Implementation of the formulation is included in the documentation.
Question 4: Benders Algorithm Implementation
Objective: Implement the Benders algorithm using the initial solution of one machine of each type. The algorithm iteratively solves the master and subproblems to refine the solution.
Code: Implemented in Q4.jl. The file also includes a table summarizing the iterations, specifying the iteration number, upper bound, lower bound, and subproblem solution objective.
Question 5: Ray-Generation Subproblem Formulation
Objective: Formulate the ray-generation subproblem to address cases where the subproblem becomes unbounded due to insufficient machines being selected in the master problem.
Code: Implementation of the formulation is included in the documentation.
Question 6: Benders Algorithm with Ray Generation
Objective: Extend the Benders algorithm to include ray generation, ensuring feasibility even when demand constraints make the subproblem unbounded.
Code: Implemented in Q6.jl. The file includes a table summarizing the iterations, including instances where the ray problem is solved.
Question 7: Stochastic Programming Introduction
Objective: Introduce stochastic programming to handle variability in daily product demand. This involves creating scenarios with different demand levels and incorporating them into the optimization model.
Code: Implemented in Q7.jl.
Question 8: Stochastic Benders Decomposition
Objective: Perform Benders Decomposition on the stochastic programming problem, formulating both the master problem and the subproblem for each scenario.
Code: Implementation of the formulation is included in the documentation.
Question 9: Advanced Benders Algorithm Implementation
Objective: Implement the Benders algorithm with ray generation for the stochastic program, summarizing the iterations and optionally utilizing callbacks and parallel processing for enhanced performance.
Code: Implemented in Q9.jl. The file includes a detailed table of iterations.
Question 9*: Advanced Implementation (Optional)
Objective: Implement the Benders algorithm using advanced techniques like callbacks and parallel processing for subproblem solutions, which can yield additional performance improvements.
Code: Implemented in Q9_star.jl.
Getting Started
To run the programs, you need to have Julia installed on your machine. Each .jl file corresponds to a specific question and contains the necessary code to solve the problem described.

License
This project is intended for educational purposes. The descriptions and formulations provided are based on standard optimization techniques and are not intended to infringe on any copyrights.
