# Safe Cocoon Plan

Status: completed

1. Specification
   - [x] Draft the Safe Cocoon component scope.
   - [x] Separate confirmed facts from proposed behavior and future non-goals.
   - [x] Define finite states, honest platform limits, accessibility, and
     emotional safety requirements.
   - [x] Review copy and open decisions with the user.
   - [x] Mark requirements and validation as approved.

2. Interaction Design
   - [x] Produce open, cocoon, and Reduced Motion designs.
   - [x] Confirm one-thumb placement at representative iPhone and Android
     sizes.
   - [x] Implement the downward gesture with an equivalent tap alternative.
   - [x] Review the design for low stimulation and non-confining imagery.
   - [x] Define final semantics, focus order, and screen-reader announcements.

3. Isolated Implementation
   - [x] Create the Safe Cocoon Flutter component after approval.
   - [x] Accept parent-owned `isClosed` and the three approved callbacks.
   - [x] Implement the open-to-cocoon transition and two stage exits.
   - [x] Keep the parent-owned back, leave, and safety controls unobstructed.
   - [x] Add Reduced Motion behavior without spatial travel.
   - [x] Avoid persistence, network, analytics, contact, and platform-control
     dependencies.

4. Isolated Validation
   - [x] Add state-transition and callback widget tests.
   - [x] Add animation interruption tests.
   - [x] Add semantics, focus order, and 44-pixel target tests.
   - [x] Test 320 logical pixels at 200 percent text scaling.
   - [x] Add and review representative visual baselines.
   - [x] Run Flutter analyzer and the relevant test suite.

5. Integration Handoff
   - [x] Review the isolated component diff.
   - [x] Confirm the component contract with the parent Need-space flow.
   - [x] Record validation evidence and known limitations.
   - [x] Do not integrate, commit, merge, push, or deploy without the required
     workflow and explicit approval.
