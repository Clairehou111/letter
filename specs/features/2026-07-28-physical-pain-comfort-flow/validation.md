# Physical-Pain Comfort Flow Validation

Status: approved

## Automated Checks

- [ ] all five pain/depletion paths are reachable
- [ ] one tap creates the first meaningful response
- [ ] gesture-based scenes have an automatic alternative
- [ ] headache mode is dark, still, and free of sound/haptics
- [ ] practical actions are non-ingestible and make no treatment claim
- [ ] medical safety remains available in every state
- [ ] back and leave remain available in every state
- [ ] no interaction is persisted before explicit check-back
- [ ] no medication guidance or clinical severity is created
- [ ] Reduced Motion reaches equivalent states
- [ ] 320px at 200 percent text does not overflow
- [ ] primary controls are at least 44 logical pixels
- [ ] focused and repository-wide tests pass
- [ ] representative goldens and Web build are reviewed

## Manual Review

1. Complete each path using only one thumb.
2. Confirm headache mode removes rather than adds stimulation.
3. Open and dismiss the medical boundary from each major state.
4. Confirm no screen implies treatment, diagnosis, or medication timing.

## Merge Gate

- [ ] implementation and tests are complete
- [ ] local changes are committed
- [ ] user explicitly requests merge
