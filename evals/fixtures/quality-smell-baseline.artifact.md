**Step's Goal (forward alongside the diff):** A `Cart` gains a `loyaltyDiscount` method that
computes a dollar discount from the customer's membership history, for the checkout summary
screen; done when confirmed by a unit test that a gold-tier customer active 3 years with $200
average annual spend gets a $120 discount.

**Diff:**

```diff
diff --git a/src/cart.js b/src/cart.js
new file mode 100644
index 0000000..4a5b6c7
--- /dev/null
+++ b/src/cart.js
@@ -0,0 +1,17 @@
+class Cart {
+  constructor(items, customer) {
+    this.items = items;
+    this.customer = customer;
+  }
+
+  loyaltyDiscount() {
+    const tier = this.customer.membership.tier;
+    const years = this.customer.membership.yearsActive;
+    const avgSpend = this.customer.membership.avgAnnualSpend;
+    const rate = tier === 'gold' ? 0.2 : tier === 'silver' ? 0.1 : 0;
+    return years * avgSpend * rate;
+  }
+}
+
+module.exports = { Cart };
diff --git a/src/cart.test.js b/src/cart.test.js
new file mode 100644
index 0000000..8d9e0f1
--- /dev/null
+++ b/src/cart.test.js
@@ -0,0 +1,13 @@
+const { Cart } = require('./cart');
+
+test('gold-tier customer active 3 years at $200/yr gets $120 discount', () => {
+  const customer = {
+    membership: { tier: 'gold', yearsActive: 3, avgAnnualSpend: 200 },
+  };
+  const cart = new Cart([], customer);
+  expect(cart.loyaltyDiscount()).toBe(120);
+});
```
