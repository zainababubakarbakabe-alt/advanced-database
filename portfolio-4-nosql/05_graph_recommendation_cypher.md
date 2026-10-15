# Graph model (design discussion) - "customers who bought this also bought"

Nodes: `(:Customer)`, `(:Product)`, `(:Category)`. Relationships: `(:Customer)-[:BOUGHT {qty, date}]->(:Product)`, `(:Product)-[:IN]->(:Category)`.

```cypher
MATCH (p:Product {id: 6})<-[:BOUGHT]-(c:Customer)-[:BOUGHT]->(other:Product)
WHERE other <> p
RETURN other.name, count(DISTINCT c) AS co_buyers
ORDER BY co_buyers DESC LIMIT 5;
```
The relational equivalent needs a self-join of `order_item` through `orders` (three joins over 600k rows); in a graph
database the traversal follows stored pointers, so cost depends on the neighbourhood size, not table size.
Not executed here (no Neo4j in the sandbox) - included as a design argument only.
