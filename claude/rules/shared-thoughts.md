# Shared Thoughts Context

Shared context between agents is placed within a `.thoughts/` directory within this workspace. It is important that you only read explicitly allowed files that pertain to your current task, otherwise you might fill up your context window with incorrect or irrelevant information. You should only read files from the `.thoughts/` directory when explicitly instructed to do so by your prompt.

## Directory Structure

The `.thoughts/` directory is structured based on pipeline stages that mirror the Engineering Design Process:

```
.thoughts/
├── problem.md
├── iterations.md
├── iteration-01/
│   ├── progress.md
│   ├── understanding/
│   │   ├── understanding-01.md
│   │   ├── understanding-02.md
│   │   ├── ...
│   │   └── understanding-NN.md
│   ├── concepts/
│   │   └── concepts-NN.md
│   └── plan/
│   │   └── plan-NN.md
│   └── implementation/
│       └── implementation-NN.md
└── iteration-02/
    └── ...
```

- `.thoughts/problem.md`: Problem statement
- `.thoughts/iterations.md`: Cross-iteration summary
- `.thoughts/iteration-NN/progress.md`: Progress summary for a single iteration
- `.thoughts/iteration-NN/understanding/understanding-NN.md`: Understanding of the problem
- `.thoughts/iteration-NN/concepts/concepts-NN.md`: Potential concepts
- `.thoughts/iteration-NN/plan/plan-NN.md`: Plan for implementation
- `.thoughts/iteration-NN/implementation-NN.md`: Summary of implementation changes

## Artifact Versioning

Directories and files are versioned with numbers like `NN`. The highest number is always the most recent version (i.e., the current version).

- The current iteration directory (e.g., `iteration-NN/`) is always the highest number
- The most recent version of a file (e.g., `understanding-NN.md`) is always the highest number
- To determine the next version: list existing files, take highest `NN`, add 1. If none exist, start at `01`.

## Iteration Detection

The `.thoughts/` directory is divided into subdirectories based on the current iteration (e.g., `iteration-NN/`). Oftentimes, a difficult problem may require multiple iterations to solve. For example, maybe we understood the problem, came up with some concepts, made a plan, but then the implementation didn't work. We would then re-evaluate our approach and begin a new iteration, following the same steps.

The current iteration directory is always the highest number. If there are no iteration directories, then this must be the first iteration (i.e., `iteration-01/`).

An agent will never need to read information from a previous iteration. The only necessary cross-iteration information is captured in the `iterations.md` file.
