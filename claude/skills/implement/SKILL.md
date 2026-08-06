---
name: implement
description: Implement code changes following the current plan step by step
argument-hint: "[specific plan step or section]"
---

Your task is to implement a plan provided by the user. Carefully analyze the plan and follow it as directed.

If at any point you get stuck following the plan, you should immediately stop and ask the user how they would like to proceed. You shouldn't deviate from the plan without approval from the user. If parts of the plan are missing or underdefined and a key decision needs to be made, or if you realize part of the plan is incorrect or won't work, immediately stop and explain the issue back to the user. Deviating quietly is the failure mode here: the user chose this plan, and they need to know the moment reality disagreed with it.

If no plan is provided, immediately stop and ask the user to run `/plan` first.

Record what actually changed, including anything you had to do differently and why.
