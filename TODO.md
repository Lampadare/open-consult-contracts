# **P1**

[-] Project/Campaign Locked Funds _>func_
[-] Locked funds _>func_
[-] Task getSubmissions _>func_

# **P2**

[-] Campaign Worker Proposal _!infra_
[-] Project Worker Proposal _!infra_
[-] Reopening campaign isn't possible.
[-] Stake can only be recovered when campaignStatus is closed or campaignStyle made open.
[-] Stake gets redistributed post-deadline if campaign isn't closed.
[-] Project Worker Proposal _>func_
[-] deadline logic! -> only check for past deadline when about to settle or close and if past campaign deadline, close project

# **P3**

[-] Crowdcheck all campaigns and metadata against harmful content.
[-] Make fundings a mapping for storage gas efficiency.

# **P4**

[-] Dynamically adjust creation stake price to be ~10$.

# **P5**

# **Removed**

[-] Task reference in project _!infra_
[-] Make a "Worker" struct which contains a "IsWorking" entry.
[-] Max workers slot (potentially in metadata if application required to join campaign).
[-] cant be more workers than tasks in settled, applications refused if not enough tasks
[-] ensure task creation keeps task deadlines within the project deadline

# **Done**

[x] Require stake to prevent spamming of campaigns.
[x] Create a "status" on campaign for closed, open and archived campaigns.
[x] Clean up functions with modifiers.
[X] Assign roles by owner.
[X] UpdateCampaign single function (default values will be placed in front-end)
[x] project nesting _!infra_
[x] Application requirement _!infra_
[x] should add project.greenlight bool variable for state of wether the workers are happy to go through with the next phase -> speedup
[x] automatic accepted if submissions are not decided on after beginning of settled period
[x] send funds to workers when going settled
[x] if owner doesn't move to settled, nothing can happen
[x] change genesis to gate and make nextmilestone at creation in a way so that the current timestamp should be settled
[x] if we are past the window of a certain phase but still havent gone to the next phase we should be able to push everything by however much time we are late
[x] solve the issue of what happens if we don't go to stage because we dont have any workers and that's the case for a long time
[x] break down update project into autoUpdater (autoUpdater takes where we at timewise and finds out where we should be and cascades through statuses depending on that) and goToSettled (necessitates Owner action and input for future milestones) also needs goToClosed! and just delete functionality for goToGenesis because can't exist really
[x] give option for owner to go to closed instead of going settled
[x] Project status _!infra_
[x] Project update status _>func_
[x] Make stage/gate infra _>func_
[x] reset fastforward array everytime we move status
[x] check for deadline when going to settled and if past deadline then go to closed
[x] EVERYTHING must be settled at every gate
[x] Remove project deadlines, make no sense and are redundant and complexify everything
[x] Worker enrollment _!infra_
[x] Application acceptance _>func_
[x] fake ^Dispute with event _>func_
[x] Worker enrollment _>func_
[x] Task submission _!infra_
[x] Remove worker function _>func_
[x] refund worker stake when they leave, only doable in gate or settled or closed _>func_
[x] worker leave function should only happen during gate or settled or closed. In stage, enrolStakes are locked and unrefundable
[x] Locked funds entry in the campaign _!infra_
[x] make a function that allows the owner to remove workers from the project at gates or settled
[x] Acceptance/declining of submissions _>func_
[x] Task submission _>func_
[x] assigning worker to task should be done in settled period
[x] function for assigning tasks to workers _>func_
[x] finalise behaviour of decision tree for submission handling
[x] Ensure if worker applies twice, previous application gets replaced by new one
[x] if adding tasks during settled, tasks can't be modified and deadline of task must be between stage start and gate start
[x] cleanup pending tasks and compute rewards need to be internal so they are never called in the wrong order
[x] functions called within the fixStatus pipeline cannot have lazyUpdater as modifier
[x] add lazyupdaters where needed
[x] calculate rewards when coming out of decision time/ going into settled
[x] update reward calculations at every settled
[x] can't update task rewards while someone is working on it
[x] clear unclosed task workers when going to settled
[x] fix memory vs storage issues
[x] none -> locked -> used
[x] none -----------> used (if refund)
[x] none <- locked
[x] fully refunded must be used when funders actually want to recover their entire available funds
[x] fully refunded can't be true unless the refund happens when amountLocked is 0
[x] lazystatusupdater must unlock rewards everytime we enter the time after the gate period decisions
[x] make sure to release funds at right time for disputes to be logical (48hrs after gate start)
[x] for accepting/declining submissions, funds should be locked until 48hrs after beginning of gate period, so dispute can be called
[x] funds involved in a dispute are locked until dispute is resolved
[x] lock funds on entry into stage
