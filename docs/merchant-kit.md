# Merchant Kit

Status: v1 implementation spec.

## Role

The Merchant is a late-game support/execution class. The class should make bad campaign pressure feel temporarily useful without replacing existing healers, stress support, or front-line damage.

Current Phase 5 balance context:

- Repair/extraction pressure already creates faction tradeoffs.
- Dread tiers already add campaign and expedition pressure.
- Existing combat skills are compact: three class skills, mostly direct damage, heal, stress, movement, torch, status.
- Existing camp skills are limited by respite, supplies, and one-use-per-camp rules.

## Base Class

Registry key: `merchant`

Display name: `Merchant`

Stats:

- HP: 19
- Speed: 4
- Resolve: 54

Rationale:

- Less durable than Warden/Exile/Apothecary.
- Slower than Duelist/Thief/Lamplighter.
- Resolve sits between Thief and Apothecary because the class profits from pressure but should not be stress-proof.

## Combat Skills

### `appraise_weak_point`

Display: `Appraise Weak Point`

- User ranks: 3, 4
- Target: enemy
- Target ranks: 1, 2, 3, 4
- Effect: apply `marked`, amount 1, turns 2
- Merchant-specific implementation: next direct hero hit against a marked target ignores armor and gains crit pressure, then consumes the mark.

Purpose: makes the Merchant useful against armored elites and bosses without becoming a main damage class.

### `brokered_mercy`

Display: `Brokered Mercy`

- User ranks: 2, 3, 4
- Target: ally
- Target ranks: 1, 2, 3, 4
- Heal: 6
- Merchant-specific implementation: add 3 stress to the Merchant after the heal succeeds.

Purpose: emergency heal with a visible personal cost. It should be weaker than Apothecary healing over time.

### `settle_accounts`

Display: `Settle Accounts`

- User ranks: 1, 2
- Target: enemy
- Target ranks: 1, 2
- Base damage: 2-4
- Merchant-specific implementation: bonus damage scales with target missing HP.

Purpose: execution pressure. It should reward finishing wounded targets, not opening fights.

## Camp Skills

### `audit_books`

Display: `Audit Books`

- Cost: 2 respite
- Target: party
- Stress heal: 4
- Merchant-specific implementation: consume one carried trinket from estate/expendable inventory when available.

Purpose: efficient stress relief bought by converting loot into paperwork loss.

### `cancel_debt`

Display: `Cancel Debt`

- Cost: 2 respite
- Target: ally
- Clear disease: true
- Merchant-specific implementation: if Survivor Enclave standing is positive, reduce `enclave_meter` by 2.

Purpose: disease cure with faction cost. The v0 `faction_survey_office` key is invalid in current registry data, so v1 uses `enclave_meter`.

## Passive

### `merchant_cut`

- Dread tier 2+: if a living Merchant is in the expedition, add 1 pack slot.
- Dread tier 4+: the first room-loot coin/relic payout gains one bonus stack.

Purpose: reverse-pressure. As the Estate degrades, the Merchant extracts better value, creating an uneasy reason to keep them around.

## Unlock

Unlock after Buried Archive Tier III completion.

Gate predicate for the event:

- `campaign.completedMissions.archive_regent == true`, or
- `campaign.bossKills.buried_archive == true`

Do not unlock from `locationProgress.buried_archive` alone. The Merchant should appear only after the Vault Regent is defeated or equivalent saved boss completion is present.

Event design for implementation:

- Event key: `merchant_ledger_offer`
- Unlock flag: `merchant_ledger_accepted`
- Class rule target: `merchant = { eventFlag = "merchant_ledger_accepted", reason = "Defeat the Vault Regent, then accept the ledger." }`
- When the gate predicate is true and the unlock flag is absent, queue an Estate return event before recruit refill.
- Accepting the event sets the unlock flag, injects one Merchant recruit into the stagecoach, then allows normal recruit generation to include `merchant`.
- Declining should keep the event available on later Estate returns; no permanent missable class unlock.

## Writing Hooks

Origin:

```lua
merchant = { origin = "The Merchant learned that mercy is an entry; debt outlasts the body." }
```

Barks:

- Arrival: `A Merchant arrives with the ledger already opened.`
- First death: `The account closed at a loss.`
- Faction shift: `A Merchant marks faction weather as price movement.`
