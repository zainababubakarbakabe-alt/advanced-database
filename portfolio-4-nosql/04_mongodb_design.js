// MongoDB design for the same catalogue + orders (mongosh).
// NOTE: written as an alternative implementation. It was NOT executed in the sandbox used to prepare this
// reference answer - run it yourself (docker run -d -p 27017:27017 mongo:7 ; mongosh < 04_mongodb_design.js)
// and screenshot your own output for your submission.
use naijacart;

db.products.insertMany([
  { _id: 6,  name: "Phone X", seller_id: 12, price: 205453.58, category: ["Electronics","Phones"],
    attributes: { ram_gb: 8, storage_gb: 128, dual_sim: true }, stock_qty: 40,
    recent_reviews: [ { customer_id: 77, rating: 4, comment: "Fast delivery" } ] },
  { _id: 7,  name: "Laptop Y", seller_id: 31, price: 640000, category: ["Electronics","Laptops"],
    attributes: { cpu: "i7", ram_gb: 16 }, stock_qty: 12, recent_reviews: [] }
]);

// Orders embed items (price snapshot) because an order is always read as a whole and never changes shape later.
db.orders.insertOne({
  customer_id: 4242, status: "PAID", order_date: new Date(),
  ship_to: { city: "Abuja", state: "FCT", street: "12 Main Street" },
  items: [ { product_id: 6, name: "Phone X", qty: 1, unit_price: 205453.58 } ],
  payment: { method: "CARD", amount: 205453.58, status: "SUCCESS" }
});

// Indexes
db.products.createIndex({ "category": 1, "attributes.ram_gb": 1, price: 1 });   // compound, multikey on category
db.orders.createIndex({ customer_id: 1, order_date: -1 });

// Query: phones with 8GB RAM under 300k, cheapest first, with execution stats
db.products.find({ category: "Phones", "attributes.ram_gb": 8, price: { $lt: 300000 } })
           .sort({ price: 1 }).explain("executionStats");

// Aggregation: revenue per payment method
db.orders.aggregate([
  { $match: { status: "PAID" } },
  { $group: { _id: "$payment.method", revenue: { $sum: "$payment.amount" }, orders: { $sum: 1 } } },
  { $sort: { revenue: -1 } }
]);

// Atomic stock decrement (single-document atomicity - no transaction needed)
db.products.updateOne({ _id: 6, stock_qty: { $gte: 1 } }, { $inc: { stock_qty: -1 } });
