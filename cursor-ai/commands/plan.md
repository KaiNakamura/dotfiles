# Planning Phase

Your task is to create a **detailed implementation plan** based on research findings.

## Context

- If `.thoughts/research.md` exists, read it first to understand the system and requirements
- If no research file exists, you may need to do basic research as part of planning
- The plan should be comprehensive yet concise, focusing on the 'what' and 'how' of changes

## Output Requirements

Generate a detailed implementation plan at `.thoughts/plan.md` that includes:

- **Step-by-step breakdown**: Every single change required, in logical order
- **File specifications**: Exact file paths that will be modified for each change
- **Code snippets**: Specific code that will be added, modified, or removed (with line number context)
- **Rollback Strategy**: How to undo changes if something breaks
- **Testing Hierarchy**: Unit → Integration → System test order
- **Performance Impact**: Expected resource usage changes
- **Security Considerations**: Authentication, authorization, data validation needs
- **Compatibility Check**: Ensure changes work with existing integrations
- **Test Cases**: Specific test cases and verification steps for each part
- **Preservation Strategy**: How existing functionality will be preserved and side effects mitigated

## Success Criteria

- Plan is significantly shorter than the actual code changes will be
- Each step is actionable with specific file paths and code locations
- Testing and verification steps are clearly defined
- Plan can be reviewed and understood without reading the full codebase
- Ready for implementation phase

## Notes

- The plan should be easy to review and ensure mental alignment
- Focus on precision: exact files, line numbers, and code snippets
- Include risk assessment for each major change
- This plan will be used by the `/implement` command to execute changes

