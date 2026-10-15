"""Renders evidence figures from the saved results/ files (excerpts, filtered by pattern).
Run from the repository root after ./run_all.sh:  python3 docs/evidence/make_evidence.py"""
import re
from PIL import Image, ImageDraw, ImageFont
F = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 13)
FB = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 13)

def pick(path, pats=None, maxw=110):
    out = []
    for l in open(path).read().splitlines():
        if pats is None or any(re.search(p, l) for p in pats):
            l = l.rstrip(); out.append(l[:maxw] + ("…" if len(l) > maxw else ""))
    return out

def render(name, title, blocks):
    rows = []
    for src, ls, full in blocks:
        rows.append(("H", ("# full file: " if full else "# excerpt from: ") + src))
        rows += [("T", l) for l in ls] + [("T", "")]
    W, H = 1000, 40 + 18 * len(rows)
    im = Image.new("RGB", (W, H), "#1e2329"); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W, 26], fill="#0b3558"); d.text((12, 5), title, font=FB, fill="white")
    y = 34
    for k, t in rows:
        colour = "#8fd18f" if k == "H" else ("#ff8a80" if ("ERROR" in t or "OVERSOLD" in t) else "#e6e6e6")
        d.text((12, y), t, font=FB if k == "H" else F, fill=colour); y += 18
    im.save(f"docs/evidence/{name}.png")

P2 = "portfolio-2-query-optimisation/results/"; P3 = "portfolio-3-transactions-concurrency/results/"
P4 = "portfolio-4-nosql/results/"; P5 = "portfolio-5-distributed-cloud/results/"
render("e1_query_plans", "Evidence 1 - Portfolio 2: execution plans and timings", [
    (P2 + "before_q1_customer_order_history.txt", pick(P2 + "before_q1_customer_order_history.txt", [r"Seq Scan on orders", r"Execution Time", r"median"]), False),
    (P2 + "after_q1_customer_order_history.txt", pick(P2 + "after_q1_customer_order_history.txt", [r"Index Scan on idx", r"Execution Time", r"median"]), False),
    (P2 + "timing_summary.txt", pick(P2 + "timing_summary.txt"), True),
    (P2 + "06_parallel_query_output.txt", pick(P2 + "06_parallel_query_output.txt", [r"q3|q4"]), False)])
render("e2_concurrency", "Evidence 2 - Portfolio 3: lost update, isolation, deadlock, retry", [
    (P3 + "03_lost_update_output.txt", pick(P3 + "03_lost_update_output.txt", [r"===", r"session", r"units sold \(stock_log\)", r"OVERSOLD", r"final"]), False),
    (P3 + "04_isolation_levels_output.txt", pick(P3 + "04_isolation_levels_output.txt", [r"Isolation level", r"T1 (first|second)", r"ERROR"]), False),
    (P3 + "05_deadlock_output.txt", pick(P3 + "05_deadlock_output.txt", [r"ERROR", r"No deadlock"]), False),
    (P3 + "06_serializable_retry_output.txt", pick(P3 + "06_serializable_retry_output.txt"), True)])
render("e3_nosql", "Evidence 3 - Portfolio 4: document model and Redis", [
    (P4 + "02_document_queries_output.txt", pick(P4 + "02_document_queries_output.txt", [r"Seq Scan on", r"Bitmap Index Scan", r"Execution Time"]), False),
    (P4 + "06_relational_vs_document_output.txt", pick(P4 + "06_relational_vs_document_output.txt", [r"relational:", r"document:"]), False),
    (P4 + "03_redis_output.txt", pick(P4 + "03_redis_output.txt", [r"DECR|SET flash|ZREVRANGE|^    -?[0-9]+$"])[:14], False)])
render("e4_distributed", "Evidence 4 - Portfolio 5: replication, synchronous commit, failover, sharding", [
    (P5 + "01_replication_output.txt", pick(P5 + "01_replication_output.txt", [r"streaming", r"replica price", r"ERROR", r"replay delay", r"sync_state now", r"still waiting", r"WARNING", r"in_recovery=false", r"write accepted"]), False),
    (P5 + "02_sharding_output.txt", pick(P5 + "02_sharding_output.txt", [r"shard [12]", r"Seq Scan on orders_s1 orders$", r"Foreign Scan"]), False)])
print("evidence figures written to docs/evidence/")
