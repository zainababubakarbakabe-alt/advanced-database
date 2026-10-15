// MongoDB design for the same catalogue + orders (mongosh).
// Run with ./run_mongo_demo.sh (resets the naijacart database first); output in results/04_mongodb_output.txt.
// Each step prints its result and checks it against the expected value (PASS/FAIL).
db = db.getSiblingDB("naijacart");

let failures = 0;
function section(title) { print("\n=== " + title + " ==="); }
function check(label, actual, expected) {
  const ok = JSON.stringify(actual) === JSON.stringify(expected);
  if (!ok) failures++;
  print((ok ? "PASS  " : "FAIL  ") + label + ": expected " + JSON.stringify(expected) + ", got " + JSON.stringify(actual));
}

section("1. Insert products (category-specific attributes, embedded recent reviews)");
const ins = db.products.insertMany([
  { _id: 6,  name: "Phone X", seller_id: 12, price: 205453.58, category: ["Electronics","Phones"],
    attributes: { ram_gb: 8, storage_gb: 128, dual_sim: true }, stock_qty: 40,
    recent_reviews: [ { customer_id: 77, rating: 4, comment: "Fast delivery" } ] },
  { _id: 7,  name: "Laptop Y", seller_id: 31, price: 640000, category: ["Electronics","Laptops"],
    attributes: { cpu: "i7", ram_gb: 16 }, stock_qty: 12, recent_reviews: [] }
]);
printjson(db.products.find().toArray());
check("products inserted", Object.keys(ins.insertedIds).length, 2);

// Orders embed items (price snapshot) because an order is always read as a whole and never changes shape later.
section("2. Insert order (embedded items, shipping address and payment)");
db.orders.insertOne({
  _id: 1001, customer_id: 4242, status: "PAID", order_date: ISODate("2026-10-13T10:00:00Z"),
  ship_to: { city: "Abuja", state: "FCT", street: "12 Main Street" },
  items: [ { product_id: 6, name: "Phone X", qty: 1, unit_price: 205453.58 } ],
  payment: { method: "CARD", amount: 205453.58, status: "SUCCESS" }
});
printjson(db.orders.findOne({ _id: 1001 }));
check("orders inserted", db.orders.countDocuments(), 1);

section("3. Indexes");
db.products.createIndex({ "category": 1, "attributes.ram_gb": 1, price: 1 });   // compound, multikey on category
db.orders.createIndex({ customer_id: 1, order_date: -1 });
const productIdx = db.products.getIndexes().map(i => i.name);
const orderIdx = db.orders.getIndexes().map(i => i.name);
print("products: " + productIdx.join(", "));
print("orders:   " + orderIdx.join(", "));
check("products compound index exists", productIdx.includes("category_1_attributes.ram_gb_1_price_1"), true);
check("orders compound index exists", orderIdx.includes("customer_id_1_order_date_-1"), true);

// Query: phones with 8GB RAM under 300k, cheapest first, with execution stats
section("4. Query: phones with 8 GB RAM under 300,000, cheapest first");
const filter = { category: "Phones", "attributes.ram_gb": 8, price: { $lt: 300000 } };
const phones = db.products.find(filter, { name: 1, price: 1, attributes: 1 }).sort({ price: 1 }).toArray();
printjson(phones);
check("matching phones", phones.map(p => p.name), ["Phone X"]);

section("5. explain(\"executionStats\") for the query above");
const exp = db.products.find(filter).sort({ price: 1 }).explain("executionStats");
const plan = exp.queryPlanner.winningPlan;
const stats = exp.executionStats;
print("winning plan:       " + plan.stage + " <- " + plan.inputStage.stage);
print("index used:         " + plan.inputStage.indexName);
print("index bounds:       " + JSON.stringify(plan.inputStage.indexBounds));
print("nReturned:          " + stats.nReturned);
print("totalKeysExamined:  " + stats.totalKeysExamined);
print("totalDocsExamined:  " + stats.totalDocsExamined);
print("executionTimeMs:    " + stats.executionTimeMillis);
check("index scan used (no COLLSCAN)", plan.inputStage.stage, "IXSCAN");
check("index name", plan.inputStage.indexName, "category_1_attributes.ram_gb_1_price_1");
check("keys examined = docs returned", [stats.totalKeysExamined, stats.totalDocsExamined, stats.nReturned], [1, 1, 1]);

// Aggregation: revenue per payment method
section("6. Aggregation: revenue per payment method (PAID orders)");
const revenue = db.orders.aggregate([
  { $match: { status: "PAID" } },
  { $group: { _id: "$payment.method", revenue: { $sum: "$payment.amount" }, orders: { $sum: 1 } } },
  { $sort: { revenue: -1 } }
]).toArray();
printjson(revenue);
check("revenue per method", revenue, [ { _id: "CARD", revenue: 205453.58, orders: 1 } ]);

// Atomic stock decrement (single-document atomicity - no transaction needed)
section("7. Atomic stock decrement (single-document atomicity, no transaction needed)");
const before = db.products.findOne({ _id: 6 }).stock_qty;
const upd = db.products.updateOne({ _id: 6, stock_qty: { $gte: 1 } }, { $inc: { stock_qty: -1 } });
const after = db.products.findOne({ _id: 6 }).stock_qty;
print("stock_qty before: " + before + ", after: " + after);
check("documents modified", upd.modifiedCount, 1);
check("stock decremented by 1", after, 39);

section("Summary");
print(failures === 0 ? "ALL CHECKS PASSED" : failures + " CHECK(S) FAILED");
if (failures) quit(1);
