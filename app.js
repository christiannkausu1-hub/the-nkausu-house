/* THE NKAUSU HOUSE — browser client. Configure SUPABASE_URL and SUPABASE_ANON_KEY below.
   The anon/publishable key is intended for browser use; database access is restricted by RLS.
   NEVER put a service-role key or database password in this file. */
(() => {
  "use strict";
  const SUPABASE_URL = "https://amwkvigiygyfofxucbta.supabase.co";
  const SUPABASE_ANON_KEY = "sb_publishable_c2qgtYSuEJPvpX6yqGSfNQ_7Qv6fsi1";
  const $ = (id) => document.getElementById(id);
  const categories = {
    income: ["Salary", "Business income", "Gift", "Interest", "Refund", "Other income"],
    expense: ["Groceries", "Rent", "Electricity", "Water", "Transport", "School expenses", "Medical expenses", "Debt repayment", "Clothing", "Communication", "Household supplies", "Other expense"]
  };
  const state = { client: null, user: null, household: null, transactions: [], page: "dashboard", authMode: "signin", inviteCode: "", busy: false };
  const money = n => new Intl.NumberFormat("en-ZM", { style: "currency", currency: "ZMW" }).format(Number(n || 0));
  const today = () => new Date().toISOString().slice(0, 10);
  const escapeHtml = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;" }[c]));
  const setMessage = (id, msg, kind = "") => { const el = $(id); if (el) { el.textContent = msg || ""; el.className = "notice" + (kind ? " " + kind : ""); } };
  const toast = msg => { const el = $("toast"); el.textContent = msg; el.classList.add("show"); window.setTimeout(() => el.classList.remove("show"), 2800); };
  const isConfigured = () => SUPABASE_URL.startsWith("https://") && !SUPABASE_URL.includes("YOUR_") && SUPABASE_ANON_KEY && !SUPABASE_ANON_KEY.includes("YOUR_");
  const currentMonth = () => new Date().toISOString().slice(0, 7);
  const sum = (list, type, month = null) => list.filter(t => t.type === type && (!month || t.transaction_date.slice(0,7) === month)).reduce((a,t) => a + Number(t.amount), 0);
  const showAuth = () => { $("authView").classList.remove("hidden"); $("appView").classList.add("hidden"); };
  const showApp = () => { $("authView").classList.add("hidden"); $("appView").classList.remove("hidden"); $("userEmail").textContent = state.user?.email || ""; };
  const errText = e => e?.message || String(e || "Unknown error");

  function setAuthMode(mode) {
    state.authMode = mode;
    document.querySelectorAll("[data-auth-tab]").forEach(b => b.classList.toggle("active", b.dataset.authTab === mode));
    $("signupFields").classList.toggle("hidden", mode !== "signup");
    $("authSubmit").textContent = mode === "signup" ? "Create account" : "Sign in";
    $("authPassword").autocomplete = mode === "signup" ? "new-password" : "current-password";
    setMessage("authMessage", "");
  }
  function navigate(page) {
    state.page = page;
    document.querySelectorAll(".page").forEach(el => el.classList.add("hidden"));
    $(page + "Page")?.classList.remove("hidden");
    document.querySelectorAll("[data-page]").forEach(b => b.classList.toggle("active", b.dataset.page === page));
    $("pageTitle").textContent = ({dashboard:"DASHBOARD",income:"INCOME",expenses:"EXPENSES",transactions:"TRANSACTIONS",household:"HOUSEHOLD SETUP"})[page] || "DASHBOARD";
    if (page === "household") renderHousehold();
    if (page === "income") renderList("incomeList", state.transactions.filter(t => t.type === "income"));
    if (page === "expenses") renderList("expenseList", state.transactions.filter(t => t.type === "expense"));
    if (page === "transactions") renderTransactions();
  }
  async function refresh() {
    if (!state.client || !state.user) return;
    const { data, error } = await state.client.from("transactions").select("id,household_id,type,amount,transaction_date,category,description,notes,created_by,created_at").order("transaction_date", { ascending: false }).order("created_at", { ascending: false });
    if (error) throw error;
    state.transactions = data || [];
    await loadHousehold();
    renderDashboard();
    if (state.page === "income") renderList("incomeList", state.transactions.filter(t => t.type === "income"));
    if (state.page === "expenses") renderList("expenseList", state.transactions.filter(t => t.type === "expense"));
    if (state.page === "transactions") renderTransactions();
    if (state.page === "household") renderHousehold();
  }
  async function loadHousehold() {
    const { data: membership, error } = await state.client.from("household_members").select("household_id,role,households(id,name,created_at)").maybeSingle();
    if (error) throw error;
    state.household = membership ? { id: membership.household_id, role: membership.role, name: membership.households?.name || "THE NKAUSU HOUSE", created_at: membership.households?.created_at } : null;
    const banner = $("setupBanner");
    if (!state.household) {
      banner.innerHTML = "<strong>Finish your household setup</strong>Create a household or join one using an invitation code before recording transactions.";
      banner.classList.remove("hidden");
    } else banner.classList.add("hidden");
  }
  function renderDashboard() {
    const tx = state.transactions, m = currentMonth();
    $("totalIncome").textContent = money(sum(tx,"income"));
    $("totalExpenses").textContent = money(sum(tx,"expense"));
    $("netBalance").textContent = money(sum(tx,"income") - sum(tx,"expense"));
    $("monthIncome").textContent = money(sum(tx,"income",m));
    $("monthExpenses").textContent = money(sum(tx,"expense",m));
    const yearSelect = $("summaryYear"), years = new Set([String(new Date().getFullYear())]);
    tx.forEach(t => years.add(t.transaction_date.slice(0,4)));
    const old = yearSelect.value;
    yearSelect.innerHTML = [...years].sort((a,b)=>b.localeCompare(a)).map(y=>`<option value="${y}">${y}</option>`).join("");
    if ([...years].includes(old)) yearSelect.value = old;
    renderMonthly();
    $("recentTransactions").innerHTML = tx.length ? tx.slice(0,6).map(transactionRow).join("") : '<div class="empty">No transactions yet. Add your first household record.</div>';
  }
  function renderMonthly() {
    const year = $("summaryYear").value || String(new Date().getFullYear()), tx = state.transactions.filter(t => t.transaction_date.startsWith(year));
    const months = Array.from({length:12},(_,i)=>({key:`${year}-${String(i+1).padStart(2,"0")}`,label:new Date(Number(year),i,1).toLocaleDateString("en",{month:"short"})}));
    const values = months.map(m=>({...m,income:sum(tx,"income",m.key),expense:sum(tx,"expense",m.key)}));
    const max = Math.max(1,...values.flatMap(v=>[v.income,v.expense]));
    $("monthlySummary").innerHTML = values.map(v=>`<div class="month-row"><div class="month-name">${v.label}</div><div class="month-bars"><div class="bar-track" title="Income ${money(v.income)}"><div class="bar" style="width:${Math.max(0,v.income/max*100)}%"></div></div><div class="bar-track" title="Expenses ${money(v.expense)}"><div class="bar expense" style="width:${Math.max(0,v.expense/max*100)}%"></div></div><div class="bar-legend"><span>In ${money(v.income)}</span><span>Out ${money(v.expense)}</span></div></div></div>`).join("");
  }
  function transactionRow(t) {
    return `<div class="transaction-row"><div><div class="transaction-name">${escapeHtml(t.description)}</div><div class="transaction-meta">${escapeHtml(t.category)} · ${escapeHtml(t.transaction_date)}</div></div><div class="amount ${t.type}">${t.type==="income"?"+":"−"}${money(t.amount)}</div></div>`;
  }
  function renderList(id, tx) {
    $(id).innerHTML = tx.length ? `<div class="table-wrap"><table><thead><tr><th>DATE</th><th>DESCRIPTION</th><th>CATEGORY</th><th>AMOUNT</th><th></th></tr></thead><tbody>${tx.map(t=>`<tr><td>${escapeHtml(t.transaction_date)}</td><td>${escapeHtml(t.description)}${t.notes?`<div class="transaction-meta">${escapeHtml(t.notes)}</div>`:""}</td><td>${escapeHtml(t.category)}</td><td class="amount ${t.type}">${t.type==="income"?"+":"−"}${money(t.amount)}</td><td><button class="delete-btn" data-delete="${escapeHtml(t.id)}">Delete</button></td></tr>`).join("")}</tbody></table></div>` : '<div class="empty">No records in this section yet.</div>';
  }
  function renderTransactions() {
    const q = $("searchTransactions").value.trim().toLowerCase(), type = $("typeFilter").value, from = $("fromDate").value, to = $("toDate").value;
    const tx = state.transactions.filter(t => (type==="all" || t.type===type) && (!from || t.transaction_date>=from) && (!to || t.transaction_date<=to) && (!q || `${t.description} ${t.category} ${t.notes||""}`.toLowerCase().includes(q)));
    renderList("transactionList",tx);
  }
  function renderHousehold() {
    const h = state.household;
    $("householdDetails").innerHTML = h ? `<div class="household-detail"><span>Household</span><strong>${escapeHtml(h.name)}</strong></div><div class="household-detail"><span>Your role</span><strong>${escapeHtml(h.role)}</strong></div><div class="household-detail"><span>Household ID</span><strong>${escapeHtml(h.id)}</strong></div>` : '<p class="muted">You have not created or joined a household yet.</p>';
    $("householdForm").classList.toggle("hidden",!!h);
    $("joinForm").classList.toggle("hidden",!!h);
    $("generateInvite").disabled = !h || h.role !== "owner";
  }
  function openDialog(type = "income") {
    if (!state.household) { navigate("household"); toast("Create or join your household first."); return; }
    $("transactionForm").reset();
    $("recordType").value = type;
    $("recordDate").value = today();
    populateCategories(type);
    $("dialogTitle").textContent = type === "income" ? "ADD INCOME" : "ADD EXPENSE";
    setMessage("formMessage","");
    $("transactionDialog").showModal();
  }
  function populateCategories(type) {
    const select = $("recordCategory");
    select.innerHTML = categories[type].map(c=>`<option>${escapeHtml(c)}</option>`).join("");
  }
  async function handleAuth(e) {
    e.preventDefault();
    if (!isConfigured()) { setMessage("authMessage","Setup needed: add your Supabase project URL and publishable/anon key in app.js, then redeploy.","error"); return; }
    const email = $("authEmail").value.trim(), password = $("authPassword").value;
    $("authSubmit").disabled = true;
    try {
      if (state.authMode === "signup") {
        const { data, error } = await state.client.auth.signUp({ email, password, options: { data: { full_name: $("displayName").value.trim() } } });
        if (error) throw error;
        if (!data.session) setMessage("authMessage","Account created. Check your email to confirm your address, then sign in.","success");
        else { state.user = data.user; await enterApp(); }
      } else {
        const { data, error } = await state.client.auth.signInWithPassword({ email, password });
        if (error) throw error;
        state.user = data.user; await enterApp();
      }
    } catch (err) { setMessage("authMessage",errText(err),"error"); }
    finally { $("authSubmit").disabled = false; }
  }
  async function enterApp() {
    showApp();
    try { await refresh(); navigate("dashboard"); }
    catch (e) { toast("Could not load household data: " + errText(e)); }
  }
  async function saveTransaction(e) {
    e.preventDefault();
    if (!state.household) return;
    $("saveRecord").disabled = true;
    try {
      const payload = { household_id:state.household.id, type:$("recordType").value, amount:Number($("recordAmount").value), transaction_date:$("recordDate").value, category:$("recordCategory").value, description:$("recordDescription").value.trim(), notes:$("recordNotes").value.trim() || null };
      const { error } = await state.client.from("transactions").insert(payload);
      if (error) throw error;
      $("transactionDialog").close(); await refresh(); toast("Transaction saved.");
    } catch (e) { setMessage("formMessage",errText(e),"error"); }
    finally { $("saveRecord").disabled = false; }
  }
  async function deleteTransaction(id) {
    if (!window.confirm("Delete this transaction? This cannot be undone.")) return;
    try {
      const { error } = await state.client.from("transactions").delete().eq("id",id);
      if (error) throw error;
      await refresh(); toast("Transaction deleted.");
    } catch (e) { toast("Could not delete transaction: "+errText(e)); }
  }
  async function createHousehold(e) {
    e.preventDefault(); setMessage("householdMessage","");
    try {
      const { data, error } = await state.client.rpc("create_household", { household_name:$("householdName").value.trim() });
      if (error) throw error;
      setMessage("householdMessage","Household created successfully.","success"); await refresh(); toast("Household ready.");
    } catch (e) { setMessage("householdMessage",errText(e),"error"); }
  }
  async function joinHousehold(e) {
    e.preventDefault(); setMessage("joinMessage","");
    try {
      const { error } = await state.client.rpc("join_household", { invitation_code:$("inviteCode").value.trim() });
      if (error) throw error;
      setMessage("joinMessage","You have joined the household.","success"); await refresh(); toast("Household joined.");
    } catch (e) { setMessage("joinMessage",errText(e),"error"); }
  }
  async function generateInvite() {
    $("generateInvite").disabled = true; setMessage("inviteMessage","");
    try {
      const { data, error } = await state.client.rpc("create_household_invitation");
      if (error) throw error;
      state.inviteCode = data; $("copyInvite").disabled = false;
      setMessage("inviteMessage","Invitation code created. Share it privately; it expires in 7 days and works once.","success");
      $("inviteMessage").dataset.code = data; toast("Invitation code created.");
    } catch (e) { setMessage("inviteMessage",errText(e),"error"); }
    finally { $("generateInvite").disabled = !(state.household && state.household.role === "owner"); }
  }
  async function copyInvite() {
    const code = $("inviteMessage").dataset.code || state.inviteCode;
    if (!code) return;
    try { await navigator.clipboard.writeText(code); toast("Invitation code copied."); }
    catch { window.prompt("Copy this invitation code:",code); }
  }
  function init() {
    document.querySelectorAll("[data-auth-tab]").forEach(b=>b.addEventListener("click",()=>setAuthMode(b.dataset.authTab)));
    $("authForm").addEventListener("submit",handleAuth);
    document.querySelectorAll("[data-page]").forEach(b=>b.addEventListener("click",()=>navigate(b.dataset.page)));
    document.querySelectorAll("[data-go]").forEach(b=>b.addEventListener("click",()=>navigate(b.dataset.go)));
    document.querySelectorAll("[data-add]").forEach(b=>b.addEventListener("click",()=>openDialog(b.dataset.add)));
    $("quickAdd").addEventListener("click",()=>openDialog("income"));
    $("transactionAdd").addEventListener("click",()=>openDialog("income"));
    $("recordType").addEventListener("change",()=>{populateCategories($("recordType").value);$("dialogTitle").textContent=$("recordType").value==="income"?"ADD INCOME":"ADD EXPENSE";});
    $("transactionForm").addEventListener("submit",saveTransaction);
    ["closeDialog","cancelDialog"].forEach(id=>$(id).addEventListener("click",()=>$("transactionDialog").close()));
    $("summaryYear").addEventListener("change",renderMonthly);
    ["searchTransactions","typeFilter","fromDate","toDate"].forEach(id=>$(id).addEventListener("input",renderTransactions));
    document.addEventListener("click",e=>{const b=e.target.closest("[data-delete]");if(b)deleteTransaction(b.dataset.delete);});
    $("householdForm").addEventListener("submit",createHousehold);
    $("joinForm").addEventListener("submit",joinHousehold);
    $("generateInvite").addEventListener("click",generateInvite);
    $("copyInvite").addEventListener("click",copyInvite);
    $("signOut").addEventListener("click",async()=>{await state.client.auth.signOut();state.user=null;state.household=null;state.transactions=[];showAuth();});
    if (!isConfigured()) setMessage("authMessage","First-time setup: follow README.md to create the Supabase project, run supabase-setup.sql, then configure app.js.","error");
    if (window.supabase && isConfigured()) {
      state.client = window.supabase.createClient(SUPABASE_URL,SUPABASE_ANON_KEY);
      state.client.auth.onAuthStateChange((_event,session)=>{ if(session?.user){state.user=session.user; if($("appView").classList.contains("hidden")) enterApp();} else if(!state.user){showAuth();} });
      state.client.auth.getSession().then(({data})=>{ if(data.session?.user){state.user=data.session.user;enterApp();} });
    }
    setAuthMode("signin");
  }
  document.addEventListener("DOMContentLoaded",init);
})();