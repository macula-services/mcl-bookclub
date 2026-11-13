"""Generate mcl-bookclub's two C4 diagrams into assets/.

Run:  python3 architecture/c4_diagrams.py

  c4-context.svg     Level 1: what the service talks to
  c4-containers.svg  Level 2: what it is made of
  c4-components.svg  Level 3: inside the command application

Drawn from the code, never from a template: the callbacks in
mcl_bookclub_service.erl, the boot in mcl_bookclub_app.erl, the store wiring in
mcl_bookclub_store.erl, the admin routes in mcl_bookclub_admin.erl, the three
department supervisors, the dependencies in rebar.config, the port and volumes in
the Containerfile and deploy/docker-compose.yml. When one of those changes, the
diagram changes in the same commit.

Colours are plain classes with a prefers-color-scheme: dark block, no CSS custom
properties (rsvg-convert renders those black), so the SVGs render the same on
GitHub, in IDE previews and through rsvg-convert.

Every thing drawn is one <g class="k-<kind>" data-name="..."> group: k-box with
its data-x/y/w/h, k-edge named by its label, k-bound, k-note, k-legend. A reader
of the SVG (a video, a slide, a test) can then pick a thing by kind and name, dim
the rest, or leave it out, without parsing shapes. After a change, render each
(rsvg-convert -w 1400 assets/c4-context.svg -o /tmp/c.png) and look at it; keep
architecture/README.md's tables in step.
"""
import os
from xml.sax.saxutils import escape

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")

SANS = '"Atkinson Hyperlegible", "Segoe UI", system-ui, -apple-system, Helvetica, Arial, sans-serif'
MONO = '"JetBrains Mono", ui-monospace, Menlo, Consolas, monospace'

# Element kinds, each (light fill, light stroke, dark fill, dark stroke).
KINDS = {
    "b-sys": ("#F5E9CC", "#A56F0A", "#3A2E13", "#E3AA3C"),   # in scope
    "b-per": ("#E3EBF2", "#3B5B7A", "#1D2A36", "#8EB4D8"),   # person
    "b-mac": ("#E6E4EE", "#5E5A78", "#26243A", "#A9A4C8"),   # Macula infrastructure
    "b-lib": ("#E7F0E8", "#4A7A55", "#1A241C", "#8FBE9B"),   # library
    "b-ext": ("#ECEFED", "#8A9791", "#1C2421", "#7D8B85"),   # external system
    "b-cmp": ("#FFFFFF", "#8A9791", "#171F1C", "#7D8B85"),   # component or container
}

STYLE = f"""<style>
.t-name {{ font-family: {SANS}; font-size: 15px; font-weight: 700; }}
.t-desc {{ font-family: {SANS}; font-size: 12.5px; }}
.t-rel {{ font-family: {SANS}; font-size: 11.5px; paint-order: stroke; stroke-width: 4px; stroke-linejoin: round; }}
.t-code {{ font-family: {MONO}; font-size: 13px; font-weight: 600; }}
.t-type {{ font-family: {MONO}; font-size: 11.5px; }}
.t-bound {{ font-family: {MONO}; font-size: 12px; font-weight: 600; }}
.t-leg {{ font-family: {SANS}; font-size: 12px; }}
.edge {{ fill: none; stroke-width: 1.25; }}
.edge-later {{ fill: none; stroke-width: 1.25; stroke-dasharray: 5 4; }}
.bg {{ fill: #FFFFFF; }}
""" + "".join(f".{k} {{ fill: {v[0]}; stroke: {v[1]}; stroke-width: {2 if k == 'b-sys' else 1.25}; }}\n" for k, v in KINDS.items()) + """\
.b-later { fill: none; stroke: #8A9791; stroke-width: 1.25; stroke-dasharray: 5 4; }
.bound { fill: none; stroke: #B3BDB8; stroke-width: 1; }
.head { fill: #3B5B7A; }
.t-name, .t-code { fill: #16201D; }
.t-type, .t-bound, .t-leg { fill: #66736E; }
.t-desc { fill: #34413C; }
.t-rel { fill: #66736E; stroke: #FFFFFF; }
.edge, .edge-later { stroke: #8A9791; }
.arrowhead { fill: #8A9791; }
@media (prefers-color-scheme: dark) {
.bg { fill: #171F1C; }
""" + "".join(f".{k} {{ fill: {v[2]}; stroke: {v[3]}; }}\n" for k, v in KINDS.items()) + """\
.b-later { stroke: #7D8B85; }
.bound { stroke: #4A5752; }
.head { fill: #8EB4D8; }
.t-name, .t-code { fill: #E6ECE9; }
.t-type, .t-bound, .t-leg { fill: #93A09A; }
.t-desc { fill: #C3CDC8; }
.t-rel { fill: #93A09A; stroke: #171F1C; }
.edge, .edge-later { stroke: #7D8B85; }
.arrowhead { fill: #7D8B85; }
}
</style>"""

DEFS = ('<defs><marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" '
        'orient="auto-start-reverse"><path class="arrowhead" d="M0 0L10 5L0 10z"/></marker></defs>')

LEGEND = [("b-sys", "In scope"), ("b-per", "Person"), ("b-mac", "Macula infrastructure"),
          ("b-lib", "Library"), ("b-ext", "External system"), ("b-cmp", "Container or component")]
BOUNDARY = ("bound", "Boundary")


class _Closer:
    def __init__(self, diagram):
        self.diagram = diagram

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.diagram.parts.append("</g>")


class Diagram:
    def __init__(self, name, title, w, h):
        self.name, self.title, self.w, self.h, self.parts = name, title, w, h, []

    def text(self, cls, x, y, s, anchor=None, rotate=None):
        a = f' text-anchor="{anchor}"' if anchor else ""
        r = f' transform="rotate({rotate} {x} {y})"' if rotate is not None else ""
        self.parts.append(f'<text class="{cls}" x="{x}" y="{y}"{a}{r}>{escape(s)}</text>')

    def group(self, k, name, **data):
        """Everything appended inside the with block becomes one named group of kind k."""
        d = "".join(f' data-{key}="{v}"' for key, v in data.items())
        self.parts.append(f'<g class="k-{k}" data-name="{escape(name)}"{d}>')
        return _Closer(self)

    def note(self, x, y, lines, name):
        with self.group("note", name):
            for i, line in enumerate(lines):
                self.text("t-desc", x, y + 18 * i, line)

    def box(self, cls, x, y, w, h, name, kind, desc, person=False, code=False):
        # A box that is too small for its own words renders as text on top of the
        # next box, which no test would catch and a reader would read as the
        # diagram saying something it does not. Fail here instead.
        need = 70 + 16 * max(len(desc) - 1, 0) + 18
        if h < need:
            raise ValueError(f"{self.name}: {name} needs height {need}, has {h}")
        for line in desc:
            if 16 + 6.2 * len(line) > w - 16:
                raise ValueError(f"{self.name}: {name}: '{line}' is wider than {w - 32}px")
        with self.group("box", name, kind=cls, x=x, y=y, w=w, h=h):
            self.parts.append(f'<rect class="{cls}" x="{x}" y="{y}" width="{w}" height="{h}" rx="10"/>')
            tx = x + 16
            if person:
                self.parts.append(f'<circle class="head" cx="{x + 26}" cy="{y + 24}" r="9"/>')
                tx = x + 44
            self.text("t-code" if code else "t-name", tx, y + 28, name)
            self.text("t-type", tx, y + 46, kind)
            for i, line in enumerate(desc):
                self.text("t-desc", x + 16, y + 70 + 16 * i, line)

    def bound(self, x, y, w, h, label):
        with self.group("bound", label, x=x, y=y, w=w, h=h):
            self.parts.append(f'<rect class="bound" x="{x}" y="{y}" width="{w}" height="{h}" rx="12"/>')
            self.text("t-bound", x + 16, y + 22, label)

    def edge(self, d, label, x, y, anchor=None, rotate=None, later=False):
        """An arrow and the words on it, one group named by the words."""
        with self.group("edge", label):
            self.parts.append(f'<path class="{"edge-later" if later else "edge"}" d="{d}" marker-end="url(#a)"/>')
            self.text("t-rel", x, y, label, anchor=anchor, rotate=rotate)

    def legend(self, y, boundary=True):
        x = 24
        with self.group("legend", "legend"):
            for cls, label in LEGEND + ([BOUNDARY] if boundary else []):
                self.parts.append(f'<rect class="{cls}" x="{x}" y="{y}" width="22" height="14" rx="3"/>')
                self.text("t-leg", x + 30, y + 12, label)
                x += 34 + 6.6 * len(label)

    def write(self):
        svg = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {self.w} {self.h}" role="img" '
               f'aria-label="{escape(self.title)}">', f"<title>{escape(self.title)}</title>", STYLE, DEFS,
               f'<rect class="bg" x="0" y="0" width="{self.w}" height="{self.h}"/>'] + self.parts + ["</svg>", ""]
        with open(os.path.join(OUT, self.name), "w") as f:
            f.write("\n".join(svg))


def context():
    d = Diagram("c4-context.svg", "mcl-bookclub system context", 1000, 680)
    d.box("b-per", 40, 30, 270, 120, "Club operator", "[Person]",
          ["Runs the club from the LAN", "admin UI: initiates, registers",
           "members, procures, plans parties"], person=True)
    d.box("b-per", 690, 30, 270, 120, "Mesh consumer", "[Person, app or service]",
          ["Calls mcl-bookclub/", "get_bookclub_by_id and",
           "subscribes to the fact topics"], person=True)
    d.box("b-sys", 365, 186, 270, 168, "mcl-bookclub", "[mcl_om mesh service]",
          ["Four apps in one OTP release:", "facade, CMD, PRJ, QRY. Its own",
           "procedure is get_bookclub_by_id;", "mcl_om adds info and get_limits.",
           "LAN admin UI on 8488, /health", "on a Unix socket"])
    d.box("b-ext", 40, 400, 270, 120, "Host disk, /data", "[External system]",
          ["The reckon-db event log and the", "sqlite read model; without the",
           "volume a recreate forgets the club"])
    d.box("b-mac", 365, 400, 270, 120, "macula-realm", "[Macula infrastructure]",
          ["Endorses the node's identity key", "and grants the scope mcl-bookclub",
           "for its action and its fact topics"])
    d.box("b-mac", 690, 400, 270, 120, "Macula stations, mesh DHT", "[Macula infrastructure]",
          ["Pinned stations are the mesh entry", "(QUIC); the DHT holds its own",
           "procedure and carries the facts"])
    d.edge("M175 150V176H400V186", "commands on 8488, and reads", 183, 170)
    d.edge("M825 150V176H620V186", "calls get_bookclub_by_id", 690, 170)
    d.edge("M420 354V400", "boot claim, scope", 428, 376)
    d.edge("M620 354V368H825V400", "advertises, publishes 3 facts", 632, 362)
    d.edge("M365 300H340V460H310", "keeps the log and the read model", 330, 340, anchor="middle", rotate=-90)
    d.note(40, 566, ["The domain stays inside: only member_registered_v1, book_procured_v1 and book_retired_v1 leave, as facts on",
                     "their own topics. The mesh never sees a command, and every query desk is answered from the local read model."],
           "the domain stays inside")
    d.legend(630, boundary=False)
    d.write()


def containers():
    d = Diagram("c4-containers.svg", "mcl-bookclub containers", 1340, 1310)
    d.bound(16, 40, 1292, 856, "mcl-bookclub [Software System] - one OTP release, four containers")
    # Row 1: the contract, its boot, its supervisor.
    d.box("b-cmp", 32, 76, 340, 136, "mcl_bookclub_service", "[mcl_om_service behaviour]",
          ["The six mcl_om_service callbacks, resolved",
           "by name; mcl-om adds info and get_limits,",
           "both open, beside them."], code=True)
    d.box("b-cmp", 492, 76, 340, 136, "mcl_bookclub_app", "[OTP application]",
          ["Opens the store from event_store/0, then",
           "lets mcl_om:boot/1 wire the mesh, the",
           "realm identity, capabilities and health"], code=True)
    d.box("b-cmp", 952, 76, 340, 136, "mcl_bookclub_sup", "[supervisor, one_for_one]",
          ["One child, the LAN admin listener.",
           "Aggregates, the stores and the handlers",
           "live in their own departments"], code=True)
    # Row 2: the mesh face, the store, the admin UI.
    d.box("b-sys", 32, 272, 340, 136, "mcl_bookclub_get_bookclub_by_id", "[macula_response provider]",
          ["handle_request/2 unwraps club_id and",
           "answers from the QRY desk; text goes",
           "back as CBOR text, booleans as 1/0"], code=True)
    d.box("b-cmp", 492, 272, 340, 136, "mcl_bookclub_store", "[this service's reckon-db store]",
          ["start_store, wait up to 30 s until it is",
           "listed, then start the evoq subscription",
           "that feeds every handler in every app"], code=True)
    d.box("b-cmp", 952, 272, 340, 136, "mcl_bookclub_admin", "[cowboy listener]",
          ["Nine POST routes through each desk's _api",
           "entry point, five GET routes through the",
           "QRY desks; MCL_ADMIN_PORT, JSON by jsx"], code=True)
    # Row 3: the three departments.
    d.box("b-cmp", 32, 468, 340, 180, "query_bookclub", "[QRY department]",
          ["bookclub_query_store: one esqlite",
           "connection, q/2 only, so a query desk",
           "cannot write. Five pure desks:",
           "get_bookclub_by_id, get_member_by_id,",
           "get_book_by_id, get_reading_by_id,",
           "get_readings_by_member"], code=True)
    d.box("b-cmp", 492, 468, 340, 180, "project_bookclub", "[PRJ department]",
          ["bookclub_read_model_store owns the DDL",
           "and every write; eight projections, one",
           "evoq_event_handler each, one INSERT OR",
           "REPLACE per event, so a replay of the",
           "log writes the same rows again",
           "idempotently"], code=True)
    d.box("b-cmp", 952, 468, 340, 180, "host_bookclub", "[CMD department]",
          ["Nine desks: initiate, archive, register,",
           "unregister, procure, retire, start and",
           "finish reading, plan_party; the",
           "on_member_registered_v1_maybe_plan_party",
           "policy and three emit_*_v1_to_mesh",
           "handlers"], code=True)
    # The libraries the release links.
    d.note(32, 706, ["The libraries every app links:"], "the libraries every app links")
    d.box("b-lib", 32, 720, 240, 136, "mcl_om", "[library, ~> 1.6]",
          ["boot/1: node key, realm join,",
           "QUIC pool, capability",
           "registration, /health"], code=True)
    d.box("b-lib", 287, 720, 240, 136, "macula", "[library, ~> 18.0]",
          ["QUIC transport, RPC by",
           "name, publish on a topic,",
           "signed DHT records"], code=True)
    d.box("b-lib", 542, 720, 240, 136, "evoq", "[>= 1.26.1, < 2.0.0]",
          ["dispatch, aggregates, the",
           "event-type registry, the",
           "$all subscription"], code=True)
    d.box("b-lib", 797, 720, 240, 136, "reckon_db + reckon_evoq", "[~> 5.4, >= 2.7.2]",
          ["the event log on disk and",
           "the adapter evoq reads it",
           "through"], code=True)
    d.box("b-lib", 1052, 720, 240, 136, "esqlite", "[library, ~> 0.9]",
          ["one sqlite file per store;",
           "the NIF connection belongs",
           "to the process that opened it"], code=True)
    # The host's environment.
    d.box("b-ext", 32, 936, 600, 104, "MCL_DATA_DIR", "[environment, /data in the image]",
          ["read by event_store/0 and by both department",
           "supervisors; the log and the read model live under it"], code=True)
    d.box("b-ext", 652, 936, 640, 104, "MCL_ADMIN_PORT", "[environment, 8488 by default]",
          ["the cowboy listener binds every interface: the admin",
           "UI is the box's LAN tool, not a mesh procedure"], code=True)
    d.box("b-ext", 32, 1068, 1260, 104, "MCL_REALM, MCL_REALM_KEY, MACULA_STATION_SEEDS, MACULA_STATION_NODE_IDS",
          "[environment: realm pair in sys.config.src, seeds and node ids via mcl_om]",
          ["the compose file refuses to start without all four, so a half-configured node",
           "never announces itself where nobody can attribute it"], code=True)
    # The wiring between the boxes.
    d.edge("M372 190H492", "reads event_store/0", 432, 182, anchor="middle")
    d.edge("M150 212V272", "capabilities/0 names the handler", 158, 246)
    d.edge("M632 212V272", "opens it before boot", 640, 246)
    d.edge("M1112 212V272", "one child: the listener", 1120, 246)
    d.edge("M150 408V468", "answers from the QRY desk", 158, 442)
    d.edge("M632 408V468", "delivers every event", 640, 442)
    d.edge("M1112 408V468", "through the _api desks", 1120, 442)
    d.note(32, 1206, ["config/sys.config.src fixes the org mcl-bookclub, pins the realm key, and carries the evoq",
                      "block that names mcl_bookclub_store; without it the subscription crashes on {not_configured, event_store_adapter}.",
                      "PRJ writes the one sqlite file and QRY reads it; a schema-contract test pins the columns one selects to the other's DDL."],
           "the config and the schema contract")
    d.legend(1268)
    d.write()


def components():
    """Level 3: inside host_bookclub, the command application. Nine desks on four
    aggregates, one policy, three emitters, drawn from apps/host_bookclub/src."""
    d = Diagram("c4-components.svg", "mcl-bookclub components: the command application", 1400, 1210)
    X = (56, 376, 696, 1016)  # four columns, one per aggregate
    # Outside the container, above: where commands come in and where events go.
    d.box("b-cmp", X[0], 60, 300, 120, "mcl_bookclub_admin", "[cowboy listener, mcl_bookclub app]",
          ["Nine POST routes, one per desk,", "each through the desk's _api module"], code=True)
    d.box("b-cmp", X[1], 60, 300, 120, "mcl_bookclub_store", "[reckon-db store, mcl_bookclub app]",
          ["One stream per club, member, book", "and reading; its $all subscription", "feeds every handler"], code=True)
    d.bound(40, 216, 1300, 760, "host_bookclub [Container] - the command application: nine desks, four aggregates, one policy, three emitters")
    # Row 1: the desks, grouped by the aggregate they address. A desk is four
    # modules: _api entry, _v1 command, maybe_ handler, _v1 event.
    d.box("b-cmp", X[0], 252, 300, 136, "three club desks", "[desk: _api, _v1, maybe_, event]",
          ["initiate_bookclub -> bookclub_initiated_v1", "plan_party -> party_planned_v1", "archive_bookclub -> bookclub_archived_v1"], code=True)
    d.box("b-cmp", X[1], 252, 300, 136, "two member desks", "[desk: _api, _v1, maybe_, event]",
          ["register_member -> member_registered_v1", "unregister_member -> member_unregistered_v1"], code=True)
    d.box("b-cmp", X[2], 252, 300, 136, "two book desks", "[desk: _api, _v1, maybe_, event]",
          ["procure_book -> book_procured_v1", "retire_book -> book_retired_v1"], code=True)
    d.box("b-cmp", X[3], 252, 300, 136, "two reading desks", "[desk: _api, _v1, maybe_, event]",
          ["start_reading -> reading_started_v1", "finish_reading -> reading_finished_v1"], code=True)
    # Row 2: the aggregates, one stream each, each with a blanket lifecycle guard.
    d.box("b-cmp", X[0], 440, 300, 136, "bookclub_aggregate", "[evoq_aggregate, bookclub_state]",
          ["One stream per club. Refuses every", "command once archived, before any", "desk sees it; status is bit flags"], code=True)
    d.box("b-cmp", X[1], 440, 300, 136, "member_aggregate", "[evoq_aggregate, member_state]",
          ["One stream per member. Refuses", "every command once unregistered;", "the member id is minted by the caller"], code=True)
    d.box("b-cmp", X[2], 440, 300, 136, "book_aggregate", "[evoq_aggregate, book_state]",
          ["One stream per book on the shelf.", "Refuses every command once retired"], code=True)
    d.box("b-cmp", X[3], 440, 300, 136, "reading_aggregate", "[evoq_aggregate, reading_state]",
          ["One stream per reading, the child", "of a member and a book. Refuses", "every command once finished"], code=True)
    # Row 3: what reacts to events: the policy and the emitters.
    d.box("b-cmp", X[0], 628, 620, 136, "on_member_registered_v1_maybe_plan_party", "[policy: evoq_event_handler, replay skip]",
          ["Every fifth member_registered_v1 dispatches plan_party_v1 to the", "club's stream. The counter is in-memory, so the cadence is", "best-effort entertainment, not a business invariant"], code=True)
    d.box("b-cmp", X[2], 628, 620, 136, "three emitters", "[emit_*_v1_to_mesh: evoq_event_handler, replay skip]",
          ["emit_member_registered_v1_to_mesh, emit_book_procured_v1_to_mesh and", "emit_book_retired_v1_to_mesh: each event becomes one fact on the mesh. A failed", "publish is an error return, so evoq's retry owns redelivery"], code=True)
    # Row 4: the application, its supervisor, and the one module that names the mesh.
    d.box("b-cmp", X[0], 816, 300, 136, "host_bookclub_app", "[OTP application]",
          ["start/2 starts host_bookclub_sup"], code=True)
    d.box("b-cmp", X[1], 816, 300, 136, "host_bookclub_sup", "[supervisor, one_for_one]",
          ["Four children: the policy and the", "three emitters. Aggregates start on", "demand under evoq's own supervisors"], code=True)
    d.box("b-cmp", X[2], 816, 620, 136, "mcl_bookclub_facts", "[the mesh contract: three facts]",
          ["Topic per fact kind; club_id and club_name in every payload, never in", "the topic; text as CBOR text, booleans as 1/0. Only it and the emitters", "may name the mesh SDK, and the department-boundary test enforces it"], code=True)
    # Outside the container, below: the mesh the facts leave on.
    d.box("b-mac", X[2], 1000, 620, 104, "Macula mesh", "[through mcl_om and macula]",
          ["macula:publish on the fact topic, with the pool and realm mcl_om holds"])
    # The wiring.
    d.edge(f"M{X[0] + 150} 180V252", "POST, through the desk's _api:handle/1", X[0] + 158, 204)
    d.edge(f"M{X[0] + 150} 388V440", "maybe_*:dispatch/1 to the club's stream", X[0] + 158, 420)
    d.edge(f"M{X[1] + 150} 388V440", "to the member's stream", X[1] + 158, 420)
    d.edge(f"M{X[2] + 150} 388V440", "to the book's stream", X[2] + 158, 420)
    d.edge(f"M{X[3] + 150} 388V440", "to the reading's stream", X[3] + 158, 420)
    d.edge(f"M{X[1] + 300} 120H1370V696H{X[3] + 300}", "the $all subscription delivers every event to the four handlers", 1384, 420, anchor="middle", rotate=90)
    d.edge(f"M{X[0]} 696H20V320H{X[0]}", "every fifth registration: plan_party_v1 to the club desks", 14, 520, anchor="middle", rotate=-90)
    d.edge(f"M{X[2] + 310} 764V816", "builds the fact, picks the topic", X[2] + 318, 796)
    d.edge(f"M{X[2] + 310} 952V1000", "publishes", X[2] + 318, 982)
    d.edge(f"M{X[0] + 300} 884H{X[1]}", "starts", X[0] + 300 + 4, 876)
    d.edge(f"M{X[1] + 150} 816V764", "supervises", X[1] + 158, 796)
    d.note(56, 1140, ["Every event a desk produces is appended to its aggregate's stream in mcl_bookclub_store (the mcl_bookclub app), and the",
                      "store's $all subscription hands it to the policy and the emitters here and to the eight projections in project_bookclub."],
           "events go to the stream, then to every handler")
    d.legend(1180)
    d.write()


if __name__ == "__main__":
    for make in (context, containers, components):
        make()
