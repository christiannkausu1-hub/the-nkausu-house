# THE NKAUSU HOUSE — Household Accounting

Updated responsive household accounting website using HTML/CSS/JavaScript, Supabase Auth + Postgres Row Level Security, and Cloudflare Pages. The existing navy, slate, grey and white visual style is retained.

## Latest usability improvements

- One shared **Add transaction** action in the top bar; duplicate add buttons were removed from Income, Expenses and Transactions so users have one consistent entry point.
- All sections use the same underlying household transaction records and refresh together after changes. Dashboard and Reports totals derive from the same transaction, account, asset and debt data, with transfers and loan principal handled separately from ordinary income/expenses.
- Mobile navigation keeps Dashboard, Income, Expenses, Transactions and Reports visible; Budgets, Savings Goals, Debts and Assets are grouped under **More**.
- Mobile layouts use larger touch targets, clearer 2-by-2 dashboard totals, simpler stacked forms and filters, wrapped action buttons, scrollable report tables, and safe-area spacing for phones.
- The service-worker cache version was increased so deployed phones can fetch the updated layout.

## Files in this package

- `index.html` — dashboard, advanced income tracking, expenses, transactions, reports, budgets, savings, debts and assets.
- `styles.css` — responsive desktop and mobile design.
- `app.js` — Supabase integration, expected and received income tracking, reports, account balances, attachments, exports, backups, restore and offline transaction queue.
- `supabase-setup.sql` — **original initial setup only**. Do not rerun it on an existing database.
- `upgrade-existing-database.sql` — additive migration for an existing installation.
- `manifest.webmanifest`, `icon.svg`, `sw.js` — installable app metadata, icon and cached app shell.

## IMPORTANT: Upgrade an existing installation safely

1. Keep your existing Supabase project, GitHub repository, Cloudflare Pages project, Auth users, household membership and records.
2. Before changing the live site, export a full backup from Reports after the new app is deployed, or create a database backup from Supabase if available.
3. Open your existing Supabase project → **SQL Editor** → **New query**.
4. Open `upgrade-existing-database.sql` from this package and copy its entire contents into SQL Editor. Read the comments at the top, then run it once. It adds columns and new tables, updates the transaction type constraint to support transfers, and applies household-scoped RLS. It also enables income planning, income targets, private income attachments and income payment tracking, plus expected/recurring expense plans, expense metadata, loan-principal links and private expense attachments. It does not drop existing tables or rows.
5. If Supabase shows an error, stop and send the exact error text before proceeding. Do not rerun the original `supabase-setup.sql` against the existing project.

The migration must succeed before the upgraded app can load the new sections because it queries the new tables. Run it once on the existing Supabase project before deploying these files. Expected income does not change account balances; only recorded payments do. Loan receipts increase cash/bank balances but are excluded from earned-income totals and also create a liability record.

## Deploy the updated files

1. Extract this ZIP.
2. Upload/replace the files in the root of the same GitHub repository connected to Cloudflare Pages: `index.html`, `styles.css`, `app.js`, `README.md`, `manifest.webmanifest`, `icon.svg`, `sw.js`, and `upgrade-existing-database.sql`. Keep `supabase-setup.sql` for reference.
3. Commit the changes to the branch Cloudflare Pages deploys from.
4. Wait for Cloudflare Pages to finish the deployment, then open the deployed site and sign in with your existing account.
5. In Supabase → Authentication → URL Configuration, make sure your actual deployed site URL is listed in allowed redirect URLs.

The Supabase URL and publishable key you supplied are already configured in `app.js`. A publishable/anon key is intended for browser use. Never use a `service_role` key, secret key or database password in the frontend.

## Included upgrades

- Transaction editing and deletion confirmation.
- Income, expenses and transfer records. Transfers subtract from one account and add to another; they are excluded from income/expense totals.
- Payment method, account, and recorded-by fields.
- Account opening balances and calculated balances for Cash, Bank, Airtel Money and MTN MoMo (the legacy Other account remains available for recorded data but is not shown as a dashboard card).
- Dashboard totals, monthly summary, recent transactions, net worth, account balances and current budget warnings.
- Monthly/yearly/all-time reports, expense category breakdown and transaction CSV export.
- Expected, partially received, overdue and recurring income plans; confirmed payments update account balances only when received.
- Monthly income targets, expected-vs-received totals, due-date calendar, overdue alerts, source breakdown, search/filter and six-month growth chart.
- Expense management with category and person filters, recipient/payee, payment method/account, monthly spend totals, category breakdown, daily calendar, six-month trend, and CSV/Excel-compatible exports.
- Expected/partially paid/overdue bills with recurrence, bill attachments, payment recording, and next-cycle creation. Unpaid bills do not reduce account balances.
- Private expense receipt attachments (up to 10 MB), duplicate-expense warnings, and budget usage adjusted for refunds.
- Refunds are recorded against an expense category, increase the account balance, and reduce net expense totals. Loan principal repayments reduce the selected debt balance and account cash without being counted as ordinary expenses.
- Private supporting income attachments (up to 10 MB), income CSV export and Excel-compatible `.xls` export.
- Loan receipts are excluded from earned-income totals, remain included in cash/account balances, and create a liability entry.
- JSON backup export and additive restore. Restore does not clear existing records; use backups privately.
- Monthly category budgets with 75% warnings and over-budget alerts.
- Savings goals with progress updates (including an emergency fund goal).
- Debts/receivables, outstanding balances and planned monthly payments.
- Asset register and net-worth calculation (assets + receivables − debts owed).
- Audit history for transaction, budget, savings, debt, asset and account opening balance changes.
- The **Settings & Access** page and invitation/join controls remain removed from the interface as requested. Existing household memberships and shared records remain in Supabase. Account opening balances are managed under **Where the Money Is**.
- Installable PWA metadata and service-worker caching of the app shell. When the app is already loaded and the device goes offline, new transaction entries can be queued locally and synced when connectivity returns.

## Accounting notes

- Current account balances = opening balances + income − expenses + incoming transfers − outgoing transfers, based only on records entered into this system.
- Net movement = income − expenses; transfers are not income or expense.
- Net worth = assets + money owed to the household − debts the household owes. This estimate is only as accurate as the values entered.
- Loan-principal repayments recorded with the principal checkbox are linked to a selected debt record and reduce its outstanding balance. Interest and fees should be recorded as ordinary expenses.
- Offline entries are stored in this browser's local storage until they sync. Do not clear browser data before syncing. Avoid using offline mode on shared/public devices.
- The PWA app shell can be cached, but Supabase authentication and cloud data require internet. This is not a fully offline database.

## Current verification status

The JavaScript syntax and package integrity are checked locally. The migration has not been run against the live Supabase database here, and the updated site has not been deployed or end-to-end tested with live accounts from this session. Those steps require access to your Supabase/GitHub/Cloudflare projects. Do not treat the app as upgraded until the migration succeeds and the new deployment finishes.


## Expense-section upgrade

- Filter actual expenses by category, owner, date range and search terms. The section shows current-month net spend, upcoming bill balances, category breakdown, a six-month trend and a daily calendar.
- Expected bills are planning records only; only a recorded payment affects account balances. Partial payments are supported, and completed recurring bills create the next cycle.
- Receipts and bill documents use a private Supabase Storage bucket. Opening a receipt uses a short-lived signed URL.
- Refunds are marked on an expense and offset that category’s net expense total while adding the refund back to the selected account. Use the same category as the original expense for the most accurate report.
- Principal repayments require selecting a debt and reduce that debt’s outstanding balance; they reduce the account balance but are excluded from ordinary expense totals. Record interest and fees as regular expenses.
- Duplicate transaction warnings are advisory only and can be overridden when two legitimate expenses match.


## Transaction ledger additions
- Search transactions by description, notes, tags, category, recipient, account, payment method or recorded person.
- Filter by transaction type, category, account, payment method, person and date range; use date shortcuts and sorting.
- Review money-in, money-out and net movement for the filtered ledger. Transfers and loan receipts are labelled separately.
- Add comma-separated transaction tags and split an expense across categories. Split parts must add up to the entered total.
- Compare a bank/mobile-money/cash balance against the recorded balance without silently changing the books.
- Reverse ordinary income, expenses and transfers with a compensating entry; the original and reversal remain visible for audit, while both are excluded from income/expense totals. Loan receipts and principal repayments should be reconciled through their linked liability records instead.
- The migration adds transaction tags and reversal metadata. Run `upgrade-existing-database.sql` on the existing Supabase project before deploying these files; do not rerun the initial setup script.


## Budget planning upgrade
The budget section now supports monthly planned income, zero-based allocation checks, household/personal/joint budget scopes, needs vs wants vs savings allocations, optional rollover, previous-month copying, applying budget templates to the next quarter or rest of the year, six-month budget-vs-spending trends, bill-due summaries, savings-goal progress, month-end balance forecasting, unusual spending-growth alerts, and CSV/Excel-compatible exports. Run the full updated `upgrade-existing-database.sql` in Supabase SQL Editor after backing up existing data. Do not rerun `supabase-setup.sql`. The app has not been tested against your live Supabase project; verify the migration in your own project before relying on the new budget features.


## Asset register upgrade
The Assets section includes acquisition cost and current valuation, ownership/share, location, linked debt and equity estimate, insurance/warranty expiry reminders (including overdue items), document/photo URL preview, monthly rental income notes, owner/category portfolio breakdown, valuation history, search/filter, CSV and Excel-compatible exports, printable reports, maintenance-cost shortcut, quick rental-income entry, acquisition/sale history and asset-sale recording. Valuation history is loaded from `household_asset_valuations`; each new asset and each changed valuation is recorded once. Before using these additions on your existing Supabase project, run the appended ASSET REGISTER UPGRADE section in `upgrade-existing-database.sql` in the Supabase SQL Editor. This migration only adds columns/table/policies; it does not delete existing records. Asset sale proceeds are recorded in the cash transaction ledger and excluded from earned-income totals; valuation changes alone are not income. The linked debt figure is a reporting estimate and should be reconciled with the Debts section to avoid double counting in net worth.
