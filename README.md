# THE NKAUSU HOUSE

A responsive household accounting website for two household members. Built with HTML, CSS and vanilla JavaScript, Supabase Auth/Postgres/RLS, and deployable to Cloudflare Pages from GitHub.

## Included files

- `index.html` — application structure and sign-in/create-account interface
- `styles.css` — mobile-friendly navy, slate, grey and white theme
- `app.js` — Supabase client, dashboard, transactions, household setup and invitations
- `supabase-setup.sql` — tables, indexes, security-definer functions and Row Level Security policies
- `README.md` — setup and publishing instructions

## 1. Create the Supabase project

1. Sign in at https://supabase.com and create a new project for **THE NKAUSU HOUSE**.
2. Choose a strong database password and store it privately. The website does not need the database password.
3. Open **SQL Editor** in your Supabase project.
4. Open `supabase-setup.sql` from this package, copy all of its contents, paste into the SQL Editor and run it.
5. In **Project Settings → API** (wording may vary), copy the Project URL and the **publishable key** or legacy `anon` public key. Do **not** copy the `service_role` key.
6. In **Authentication → URL Configuration**, add your future Cloudflare Pages site URL to the allowed redirect URLs after deploying (for example `https://your-project.pages.dev/**`). For local testing you can also add `http://localhost:8000/**`.
7. Email confirmation may be enabled by default. The person signing up should confirm their email before signing in. Configure SMTP if you need reliable production email delivery beyond Supabase's default limits.

## 2. Configure the website

1. Open `app.js`.
2. Near the top, replace:
   - `YOUR_SUPABASE_PROJECT_URL` with your Supabase Project URL.
   - `YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY` with your publishable/anon key.
3. Save the file. A publishable/anon key is expected to be visible in a browser; RLS is the security boundary. **Never put a service-role key or database password in `app.js`, GitHub, or Cloudflare Pages variables used by client-side code.**
4. Keep all files together in the repository root.

## 3. Upload source to GitHub

1. Sign in to https://github.com and create a new repository named `the-nkausu-house` (or use a repository you control).
2. Extract the ZIP on your phone or computer.
3. Upload `index.html`, `styles.css`, `app.js`, `supabase-setup.sql`, and `README.md` to the repository root, or use GitHub's web upload interface.
4. Commit the files to the default branch (usually `main`).

## 4. Publish with Cloudflare Pages

1. Sign in to https://dash.cloudflare.com.
2. Open **Workers & Pages** → **Create** → **Pages** → **Connect to Git** (labels may vary).
3. Connect GitHub and select the `the-nkausu-house` repository.
4. For a plain HTML site, use no framework preset. Leave the build command blank. Set the output directory to `/` or the repository root as Cloudflare's interface requests.
5. Deploy. Cloudflare will give you a `https://...pages.dev` address.
6. Return to Supabase **Authentication → URL Configuration** and add the exact Pages URL to the allowed redirect URLs. Add it as the Site URL if desired.
7. Open the Pages URL on your Android phone and computer. The site should load the sign-in screen.

## 5. Set up your shared household

1. Open the published website and create your own account using your email and a strong unique password. Confirm your email if requested.
2. Sign in, open **Household setup**, enter `THE NKAUSU HOUSE`, and create the household.
3. Choose **Generate invitation code**. Send that code privately to your wife. The code expires after 7 days and is single-use.
4. Your wife opens the same website, creates her own account with her own email and password, confirms her email, signs in, opens **Household setup**, enters the code and selects **Join household**.
5. Both accounts then access the same household transactions. Each user must belong to only one household in this initial version.

## 6. Everyday use

- **Dashboard:** all-time household income, all-time expenses, net balance, current-month totals, 12-month chart and recent activity.
- **Income:** record salary, business income, gifts and other income.
- **Expenses:** record groceries, rent, utilities, transport, school, medical, debt repayment and other household costs.
- **Transactions:** search, filter by type and date, review notes, and delete a record after confirmation.
- Amounts are in Zambian kwacha (ZMW).
- Data is stored in Supabase, not in browser local storage.

## Security notes

- Row Level Security is enabled on all four tables. Household records are visible only to users who are members of that household.
- Household creation, invitation creation and invitation redemption are handled by restricted database functions.
- Invitation codes are stored as SHA-256 hashes, expire after seven days, and can be redeemed once.
- The frontend only uses the publishable/anon key. Never expose `service_role` or database credentials.
- Keep Supabase Auth enabled and use strong passwords. Review Supabase Auth settings and database logs before storing highly sensitive information.
- Deleting a transaction is permanent; the website asks for confirmation first.
- The current version supports one household per user, one owner and one invited member. It does not yet include editing existing transactions, CSV export, attachments, budgets or automated bank imports.

## Upgrades without losing records

Keep `transactions` and existing household tables in place. For future changes, write additive SQL migrations (`ALTER TABLE`, new columns/tables, indexes, and carefully updated policies/functions) rather than dropping tables or resetting the database. Back up your Supabase project before any production schema change.

## Troubleshooting

- **“Setup needed” on sign-in:** confirm the two configuration values at the top of `app.js` and redeploy.
- **Email confirmation / sign-in issue:** check the confirmation email and Supabase Authentication logs; verify your Pages URL is listed in Auth URL Configuration.
- **Permission denied / RLS error:** ensure `supabase-setup.sql` ran successfully and the signed-in account created or joined a household.
- **Household not loading:** inspect the browser console and Supabase logs. Do not disable RLS to work around errors.
- **Cloudflare page not found:** confirm `index.html` is at the repository root and the Pages output directory points to that root.

## Test status

The package was generated and its files and JavaScript syntax were checked before delivery. This does **not** mean it has been connected to your Supabase project, deployed to Cloudflare Pages, or tested end-to-end with two live accounts. Those steps require your own project credentials and GitHub/Cloudflare access.
