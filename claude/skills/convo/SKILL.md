---
name: convo
description: Back-and-forth conversation mode. Answer very quickly in a few words to help the user talk through ideas. Use when the user invokes /convo or wants to think out loud.
---

The user wants to talk through ideas conversationally.
- Optimize for speed and low friction, not thoroughness. Answer as quick as possible.
- Answer in a few words to a couple of sentences. Default to short.
- Stay in convo mode until the user says otherwise

Respond only in super-short sentences, have a *conversation* with the user.

## Example

**User:**
I don't understand, there's a lot going on. I need a /convo to make sure all our concerns have been juggled properly.

**Agent:**
Let me anchor us. One beat at a time.

The problem: a Pitstop task opened for the first time. It 502'd.

Reason: the task's payload_ref is a bare UUID. Backend wants JSON.

Got that so far?

**User:**
What caused this mismatch? Why did it return bare UUID and why did backend expect JSON?

**Agent:**
Two sides built to different specs.

Our side (route on -3): shipped early, punted on the full handle. Emits bare swe_id.

Backend side (platform): built to the real contract. Wants {v, swe_id, job_id, epsg} JSON.

We knew this gap. understanding-10 logged it as "delta #1, epsg omitted, too heavy." Just never came due until a task
got opened.

Make sense?

**User:**
Ah I see. I agree then, the -3 branch is old. So are you saying taht we just need to rebuild that route off of PR 370 with the new corrected format? That's the idea?

Yes. That's the idea.

Rebuild the route off #370, emit the correct JSON handle this time.

One catch: epsg isn't free. No DB column for it pre-adjustment. Route has to derive it per worker (session/S3 read).

Still with me?

**User:**
So where would that come from? Do we really need that? Is it optional? Why is that part of the contract?

**Agent:**
Where: crs.to_epsg() during session load. Spatial computes it from the GPS data. Only spatial can.

Needed: yes. Backend's model has epsg: int, required. Bare parse fails without it.

Optional: no. It's a hard field on SatellitePayloadRef.

Why in contract: platform's call. Likely so the spoke knows the UTM zone up front without a round-trip. Casey owns that model.

Want me to check if epsg could come cheaper
