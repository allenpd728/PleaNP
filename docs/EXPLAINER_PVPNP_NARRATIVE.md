# The P vs NP Story, in Plain Words

*A beginner-friendly telling of a famous math problem, the tools people use to study it, and how the PleaNP project is set up to help — written so anyone can follow along, even with no math or computer background.*

---

## Part 1: The puzzle that pays a million dollars

There is a riddle in math that has confused people for over fifty years. It is
called **P vs NP**. No one has solved it. The Clay Mathematics Institute offers
a million dollars to anyone who can.

The riddle is about two ideas: **checking** and **solving**.

Imagine someone hands you a giant jigsaw puzzle, already finished. It is easy
to *check* that the pieces fit. It is hard to *solve* the puzzle yourself.

Or imagine a friend gives you a huge math worksheet with the answers already
written. It is quick to *check* the answers. It is slow to *do* the worksheet
from scratch.

The riddle asks: **Are these two things the same?**

- **P** stands for problems where the *solving* is fast. (Think "quick
  problems.") The P comes from a math word for "speedy," but you can think of
  it as "practical" or "fast."
- **NP** stands for problems where the *checking* is fast, even if the solving
  is hard. (Think "checkable" and you have the right idea.)

So the question is really: **Is every problem that is quick to check also
quick to solve?**

If the answer is **yes** (P equals NP), then many things we think are hard
today — breaking secret codes, solving giant puzzles, finding the best route
— could suddenly become easy. That would change the world.

If the answer is **no** (P is not NP), then some problems will always stay
hard no matter how clever we get. Most people think this is the real answer,
but nobody can prove it.

The hard part is not guessing the answer. The hard part is **proving** it.

---

## Part 2: The machine that follows rules

To even *talk* about "fast" and "slow," we need to agree on what a computer
is. There is a famous make-believe machine called a **Turing machine**. It is
very simple. Picture a robot with:

- a long tape with boxes on it,
- a pencil, and
- a set of printed instructions, like a recipe.

The robot reads one box, looks at its instructions, and does exactly what the
recipe says: it might draw a mark, erase a mark, move one box left or right,
or stop. That's it. It has no ideas, no feelings, no shortcuts. It just
follows the recipe, step by step.

Why do we care about this boring robot? Because **anything** any computer can
do, this robot can do too — if we give it enough time and tape. So when
mathematicians want to talk about "what can a computer do and how long does it
take?", they talk about the robot. It is the base measuring stick.

In the PleaNP project, these robots are written in a special language so the
computer can check their work carefully. That is where **Lean** comes in.

---

## Part 3: The magic black box (oracles)

Now we add a fun twist to the robot: a **magic black box**.

Imagine the robot can ask a question to a box that always answers "yes" or
"no" instantly. The robot doesn't know *how* the box works. It just asks, and
the box answers. Mathematicians call this box an **oracle**.

Why add a magic box? Because we want to ask: **what if checking a hard
problem were free?** If the box already knows the answer to every puzzle,
then some problems suddenly look easy. The robot stops being only the robot;
it becomes "the robot plus the box."

Scientists use this idea to explore the edge of the problem. They ask: *even
with a magic box, is there still a hard problem?* And the answer gets
surprising.

---

## Part 4: The three walls (barriers)

Over the years, smart people have found three huge **walls** — call them
barriers — that block every attempt to solve P vs NP so far. It is not that
people ran out of ideas. It is that whole *families* of ideas were shown to be
unable to work. Trying to break through these walls with the wrong tool is
like trying to open a lock with a key that is known to be the wrong shape.

**Wall 1 — Relativization (1975).** Three scientists (Baker, Gill, and
Solovay) showed something strange. If you let robots use the magic box, you
can make the answer "yes" with one box and "no" with another box. A method
that works with any box can never settle our question. We call such a method
**relativizing** — and if your idea relativizes, it hits a dead end.

**Wall 2 — Natural proofs (1994).** Two scientists (Razborov and Rudich)
showed that a whole popular style of proof — "natural" proofs that spot
patterns in hard problems — would secretly break secret codes. Since we want
secret codes to stay unbreakable, this style of proof cannot be the answer.

**Wall 3 — Algebrization (2008).** Two more scientists (Aaronson and
Wigderson) found a third wall that even dodges the first two. Some methods
get past Wall 1 but still hit this one.

Here is the key idea for this project: **before you try to solve P vs NP, you
first need a map of these walls**, so you do not waste time walking into them.
That is exactly what PleaNP is building.

---

## Part 5: The computer that checks the math (Lean)

Here is a problem with math papers: people make mistakes. Even smart people.
A single small mistake can quietly ruin an entire proof, and it may go
unnoticed for years.

Some computer scientists decided to fix this. They built a program called a
**proof assistant**. You write your math idea in a special language, and the
computer checks every single step. If every step is correct, the computer
says, "Yes, this is solid." If any step is wrong, the computer says, "No,
here is the error." It is like spell-check, but for math.

The one used here is called **Lean 4**. It is free, built by a community of
mathematicians, and it is extremely strict — which is exactly what you want
when you are trying to prove something important and easy to get wrong.

But here is the honest catch: **Lean only checks the logic.** It does not
check if you wrote down the *right question*. You could prove a perfect
theorem about the wrong thing, and Lean would happily approve it. So the
hardest part of this project is being sure the question being checked is
*the real question*. Most of PleaNP's clever machinery is about that.

---

## Part 6: How PleaNP is put together

**PleaNP** is a project that builds, inside Lean, the first careful map of the
three walls, so that future attempts to solve P vs NP can be checked honestly.

Here is the setup, in layers:

**Layer 0 — The playing field.** PleaNP writes down the robots (Turing
machines), the magic boxes (oracles), and the speed idea (fast vs slow) as
real Lean math objects. These become the pieces every later statement talks
about.

**Layer 1 — The walls themselves.** PleaNP states the three barriers
(relativization, natural proofs, algebrization) as Lean statements — precise,
checkable sentences. The goal is to prove them, one by one.

**Layer 2 — The wall-detector.** PleaNP built a tool that can look at a math
claim and say: "this claim survives the walls, or this claim walks straight
into one." It uses a special tag called **Relativizing**. If a claim carries
the tag, the tool warns "dead end." If not, it says "maybe." This turns the
folklore "don't try these methods" into an automatic check. The tool is
called **`#barrier_check`**.

**Layer 3 — The honesty gate.** Because proving the wrong thing is the
project's biggest fear, PleaNP built a set of **gates** — automatic checks
that every claim must pass before anyone trusts it:

- a **hygiene scan** that rejects any proof with a "we'll finish this later"
  hole (called a `sorry` in Lean),
- a **vacuity scan** that rejects claims that are secretly empty (saying "true
  because nothing really happens"),
- an **axiom check** that makes sure no hidden cheat was smuggled in,
- a **read-back check** that translates the Lean statement back into plain
  English so a human can spot if the machine proved the wrong sentence.

**Layer 4 — The human review loop.** A person (even one with no math
background) does not need to read Lean. Instead, the project turns each claim
into **one simple yes/no question** — like "does this say *for every* magic
box, or *for one* magic box?" The person answers in a chat-style comment on a
GitHub issue: "yes, that's what I meant" or "no, flag it." If there is any
doubt, a special trick re-asks a twisted version of the same claim, to keep
the reviewer awake and honest.

**Layer 5 — The AI engine.** This is where artificial intelligence helps.
Here is the plan:

1. **Many tries.** Several AI helpers each write their own version of a
   statement, working alone, without seeing each other's work.
2. **Compare.** The machine checks whether all the versions actually say the
   same thing. If they agree, the statement is probably right. If they
   disagree, that is a clue — the question itself might be fuzzy, and a human
   gets asked to settle it.
3. **Confirm.** A person reviews the survivors, one simple question at a time.
4. **Prove.** Finally, an AI tries to prove the agreed statement, and Lean
   checks the proof step by step.

Each round of "many tries → compare → confirm → prove" is like panning for
gold: most attempts wash away, and the few solid pieces stay.

---

## Part 7: How the team keeps order (the GitHub workflow)

The project uses **GitHub**, a website where code and tasks live together.
It runs like a small factory:

- **One task = one ticket.** Every piece of work gets its own issue, with a
  clear description of when it is "done."
- **Agents pick up tickets.** An AI agent claims a ticket, does the work, and
  proves it is done by showing the checks pass.
- **No one works on the same ticket twice.** A tagging system (labels like
  "available," "claimed," "done") makes sure two helpers never grab the same
  job.
- **Machines check every change.** A robot called **CI** runs all the checks
  automatically every time new work appears. Red checkmark = something broke.
  Green checkmark = everything is still solid.
- **The human is the judge of meaning.** The human never needs to read Lean
  or follow the proof. They only answer simple yes/no questions about what
  the statements are supposed to mean. That is their whole job — and it is
  the one job a machine cannot do.

---

## Part 8: What success looks like

If everything works, PleaNP will deliver three things:

1. **A map of the walls** — the first machine-checked, community-verifiable
   statement of why the three barriers block P vs NP.
2. **A honest checker** — a free tool any future researcher (or anyone) can
   use to test whether their approach to P vs NP walks into a known wall.
3. **A trustworthy pipeline** — proof that AI can do serious math work, as
   long as a careful human keeps pointing at the *meaning*, and strict
   machines keep checking the *logic*.

The million-dollar answer to P vs NP is probably still far away. But the
groundwork — the map, the checker, and the honesty — is exactly what a real
attempt needs. And that groundwork is worth building even if the big prize
takes another fifty years.

---

## One-paragraph version

P vs NP asks whether every problem that is quick to check is also quick to
solve. Mathematicians think the answer is no, but proving it is very hard,
partly because three known walls block whole families of attempts. The PleaNP
project writes down the robot-machines, the magic oracle boxes, and the three
walls in a computer language called Lean that checks every logical step. It
builds tools that detect the walls automatically, gates that reject empty or
cheated proofs, a simple yes/no review loop for a human (no math needed), and
an AI pipeline where many helpers each try a statement, the machine compares
them, and a human confirms the meaning. The goal is the first honest,
machine-checked map of the P vs NP walls — a serious contribution even if the
big prize stays unsolved.