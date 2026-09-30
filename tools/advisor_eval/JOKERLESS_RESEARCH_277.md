# Jokerless research and development priorities — 2026-09-13

User requested Reddit/wiki research, tailored4OAK/5OAK/Flush openings, improvements
ordered by expected impact, continuous installs, and a report on win-rate gain.
No numerical uplift is supportable. Selected synthetic complete attempts are
failure evidence, not an unbiased player cohort. Neither current nor projected
rates are established; tests/features do not imply wins.

## Findings

Player reports repeatedly favor early Mars, Blue seals, rank development via
Strength/Death, and later Glass/Steel. Four of a Kind leaves a fifth played-card
slot, helping with Cerulean Bell's compulsory selection; it is not immune to bad
draws or other boss effects. Flush is viable with suit concentration and stronger
scaling support. Five of a Kind requires enough copies and should not discard an
already developed Four of a Kind level advantage without comparing actual scores.
Early versions of some guides predate Straight and Blue Seal balance changes.
Anecdotal claims of easy/first-try success are not win-rate evidence.

Sources read Sep13:
- https://www.reddit.com/r/balatro/comments/1tgj8aw/jokerless_tips/
- https://www.reddit.com/r/balatro/comments/1bx1jhf/anyone_got_tips_for_jokerless/
- https://www.reddit.com/r/balatro/comments/1uuxc3v/please_help_jokerless/
- https://balatrogame.fandom.com/wiki/Planet_Cards
- https://balatrogame.fandom.com/wiki/Card_Modifiers

Wiki extracted text confirms Mars+30Chips/+3Mult, Jupiter+15/+2, PlanetX+35/+3;
Blue generation needs held seal and free space; Glassx2 can break and Steelx1.5
works held. Wiki direct pages sometimes fail; indexed source text was available.
Runtime mechanics are checked against original executable ZIP/source, with
isolated workers only when registered. Advice is a hypothesis to test, not rules
that override observed resources, survivability or whole-inventory protections.

## Implemented in priority order

1. 275: exact held main-hand Planet preparation without uncertain scoring gating.
   Final-boss source5 retained twoSaturn. Dependent source6 used a Saturn earlier,
   changed the trajectory and lostAnte3Eye. No automatic gain/rescue is claimed.
2. 276: concentrated-rank completion candidates share the existing score budget;
   smaller held pairs can beat exhausted triples after visible rank development.
3. 277: bound Mars/FourKind and Jupiter/Flush opening search presets, twoBlue
   includingoneSteel. Existing Saturn recipes remain reproducible. Search proves
   only an opening under its public catalog; affordability and survival still
   depend on actual play. Initial hidden PlanetX is correctly excluded.
4. Pending source evidence: targeted rank/suit development, lateGlass/Steel value,
   preservation versus spending, and missing mechanics such as revealed-packFool.

The search order changed while rank work was independent of Core work; both were
installed as soon as their coherent component tests passed. Shared one-use caps
were retained through shutdown/resume and the research steering.
