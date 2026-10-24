# Financial health indicators (WM-11)

Open Settings → Indikator Keuangan. This is a read-only personal IDR assessment from the local financial ledger, WM-06 obligations, WM-08 goal reservations and the WM-09 emergency plan. It provides no composite score, benchmark thresholds or personalized recommendations. It never writes financial transactions or makes API requests to calculate results.

## Scope and assumptions

Choose 3, 6 or 12 completed calendar months, owned active leaf cash accounts and whether to include net investment dividends in income. The page uses the display timezone selected in Settings (device/WIB/WITA/WIT). Calendar boundaries are converted to half-open UTC instants for ledger queries. Defaults are three months, all currently eligible accounts and dividends excluded. The current partial month is excluded. For example, October's three completed WIB months cover July 1 through September 30 in WIB. The repository's optional timezone argument retains UTC semantics for existing callers that omit it. Ratios, account scope and debt/investment exclusions are unchanged; the emergency fund baseline retains its own plan rules.

The primary view shows four compact metrics. Each opens its formula and exact inputs in a detail sheet. Full account lists, assessment timestamp, evidence warnings and assumptions remain available under details instead of filling the primary view. Amounts use grouped Rupiah and percentages use Indonesian decimal punctuation. Open detail sheets withhold their contents after a session/privacy change. There are no raw UTC timestamps in the page.

Assumptions persist atomically in the current owner's local store, only on this device. They do not enter the sync queue, change the emergency plan or require a backend migration. A restored owner-specific selection that is empty or no longer valid withholds indicators until corrected; it does not silently substitute other accounts. New accounts are not automatically added to an explicitly saved selection.

Exclude other owners' accounts, non-IDR balances, investment accounts, parent accounts and mapped obligation accounts. Historical flows use the same currently eligible account selection; deleted/reclassified accounts' history is outside this scope. Activity by other authorized actors on an owned selected account is included. The UI shows account names, calculation time, period and number of included income/expense rows. Current liquidity is a snapshot at calculation time, not the balance at the historical period end.

## Formulas

All calculations use integer minor units (`BigInt`), never floating-point money. Percentages use hundredths of one percent. Months use hundredths of one month. Display truncates toward zero to two decimals. Values are not clamped to a score range.

Let I be recorded income, E recorded expenses, N the selected number of months, P actual payable principal repaid, D actual payable debt service and C current free cash:

| Indicator | Formula | Interpretation |
| --- | --- | --- |
| Saving rate | (I − E) / I × 100% | Recorded operating surplus; can be negative. It is not net-worth growth. |
| Debt-service burden | D / I × 100% | Actual payable repayments in the period; can exceed 100%. |
| Free-cash liquidity | C × N / (E + P) months | Current unearmarked cash against the historical monthly average of expenses plus payable principal. |
| Emergency coverage | WM-09 liquid funds / WM-09 monthly essential baseline | Reuses the emergency plan's separate account/category/goal selections and manual or estimated baseline. |

I and E include live INCOME/EXPENSE ledger rows in the period and selected accounts. Transfers, loan principal and investment BUY/SELL settlements are excluded. Net dividends enter I only when explicitly enabled and linked trade evidence is available. Payable interest and fees remain expenses, so they affect both the saving-rate expense numerator and actual debt service, each once. Receivable interest remains recorded income and receivable fees remain recorded expenses.

D is the sum of principal, interest and fees of owned, unreversed, live WM-06 REPAY events for PAYABLE obligations paid from selected cash accounts within the same period. P is their principal only. Receivable repayments, loan openings, reversals, future installments and unpaid/skipped bills are excluded from D and P. Nonzero repayment components require matching live cash ledger evidence. Missing debt identity or mismatching evidence withholds flow indicators rather than returning a false zero. Loan payments without a cash account are outside the selected cash scope.

C sums max(0, positive account balance − own active goal reservations) per selected account using WM-08's existing availability calculation. Goal allocations do not create expenses. All earmarks, including emergency goal earmarks, are excluded from general free cash. WM-09 can separately include backed allocations of its explicitly linked emergency goal: this is a different indicator, not another quantity to add to C. Negative cash balances contribute zero available cash and produce an explicit warning.

The liquidity calculation divides once using C × N / (E + P); it does not round a monthly average first. E already includes interest/fees, so only P is added. Months without entries remain in N. For I=1000, E=215, P=100, D=115, C=1000 and N=3, saving rate is 78.50%, burden 11.50% and liquidity 9.52 months.

## Completeness and limitations

Flow indicators require completed transaction, investment and obligation snapshots; goal and plan-dependent results require their corresponding owner-scoped coverage at the current sync cursor. An active sync withholds results until it completes. These checkpoints establish device feed coverage, not proof that all real-life transactions were recorded or that the API is currently reachable. The UI labels results as local estimates and warns about pending/rejected/conflicting mutations, which remain represented in provisional local values.

Zero or unknown income yields unavailable saving/debt ratios. Zero or unknown expenses plus principal yields unavailable liquidity months. An absent plan, empty emergency account selection or unknown/zero emergency baseline yields unavailable emergency coverage. A missing or unclassifiable investment settlement and a protected outgoing loan settlement without owned evidence withhold flow ratios. Unknown values never become infinity, an implied healthy score or a fabricated zero.

The UI exposes counts of months with recorded income and expenses and flags sparse history. It retains WM-09's warnings and baseline period/mode. Account and ratio amounts respect hidden-balance mode. Session changes prevent stale dialogs from saving the prior user's assumptions. Links to Dana Darurat and Tagihan & Jadwal let the user inspect their inputs; scheduled bills are not treated as actual payments and no cash-flow forecast is implied.

Validation covers both snapshot and encrypted indexed stores, exact arithmetic beyond floating-point precision, half-open UTC periods and pagination, reversals, evidence gaps, exclusions, reservation backing, persisted assumptions, rollback, hidden values, narrow-screen layout and stale-session saves. Device/emulator runtime is not claimed.
