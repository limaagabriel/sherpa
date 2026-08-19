**Step's Goal (forward alongside the diff):** A `paginate` helper returns one page of `items`, for
the results-list view because rendering the whole list at once is slow; done when confirmed by a
unit test that page 0 of a 10-item list at page size 4 returns exactly 4 items.

**Diff:**

```diff
diff --git a/src/paginate.js b/src/paginate.js
new file mode 100644
index 0000000..1a2b3c4
--- /dev/null
+++ b/src/paginate.js
@@ -0,0 +1,5 @@
+function paginate(items, pageSize, pageIndex) {
+  const start = pageIndex * pageSize;
+  const end = start + pageSize;
+  return items.filter((_, i) => i >= start && i <= end);
+}
diff --git a/src/paginate.test.js b/src/paginate.test.js
new file mode 100644
index 0000000..5d6e7f8
--- /dev/null
+++ b/src/paginate.test.js
@@ -0,0 +1,6 @@
+const { paginate } = require('./paginate');
+
+test('page 0 of 10 items at size 4 returns 4 items', () => {
+  const items = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
+  expect(paginate(items, 4, 0)).toEqual([0, 1, 2, 3]);
+});
```
