<h1>v7.29 Deferred Clearing + Per-Group Band Re-Write Test Log</h1>
<p><strong>Generated:</strong> 2026-06-12 10:13:26<br><strong>Specimen:</strong> comprehensive_save.specimen</p>
<hr>
<h2>Purpose</h2>
<p>Verify v7.29 deferred clearing fix. The shared temp list (_CURRENT_BAND_INFO, _CURRENT_RELATION_SCORES, etc.) now survives until ALL per-lobe rendering is complete. Each non-primary multipart group gets its own band re-write before COMMANDS fires, so band_of() returns correct assignments instead of :unknown. Math answers should be correct. Multipart responses should be coherent per-clause. Mutual incompleteness from v7.28 should still work.</p>
<hr>
<h2>Specimen Load</h2>
<blockquote> <p>  🧹 Wiping current cave state...
  ✅ Cave wiped clean. Beginning restore...
  🔢 ID counters restored (node=19, msg=4)
  🗳  Last voters restored (0 IDs)
  👁  Eye state restored
  🔧 Verb registry restored (5 classes, 24 verbs, 2 synonyms)
  🔤 Thesaurus restored (511 words)
  🧠 Lobes restored (5)
  📋 Lobe tables restored (0)
  🌱 Nodes restored (19)
  ⚡ Hopfield cache restored (0 entries)
  ⚙️  Rules restored (9)
  🚫 Inhibitions restored (3)
  💬 Messages restored (4 total, 1 pinned)
  👁  Arousal restored (level=0.65)
  🧬 BrainStem state restored
  🔗 Attachments restored (1)
  🔮 Trajectory restored (0 entries)
  🕐 Temporal coherence restored (0 entries)
  ⏳ Morph cooldowns restored (0 active)
  🛡 Immune system restored (1 signatures, 3 ledger entries)
  🤖 AIML system restored (2 nodes across 2 lobes)
  🔢 @sigil:math seed nodes created (specimen had none)
  🔗 @sigil:multipart seed node created (specimen had none)
</p> </blockquote>
<p><strong>Nodes:</strong> 22 · <strong>Lobes:</strong> 5<br>math: 4 nodes, subject="mathematical concepts"<br>philosophy: 4 nodes, subject="philosophical concepts"<br>science: 3 nodes, subject="scientific concepts"<br>technology: 3 nodes, subject="technology concepts"<br>nature: 2 nodes, subject="natural world concepts"</p>
<hr>
<h2>Multipart Test Inputs</h2>
<h2>Test — simple_arithmetic</h2>
<p><strong>Input:</strong> <code>what is 2 plus 2</code></p>
<blockquote> <p>[Multi-clause reasoning voice] 2 plus 2 equals 4.</p> </blockquote>
<p><br></p>
<details> <summary><strong>📊 Telemetry — click to expand</strong></summary>
 <table class="e-rte-table"> <thead> <tr> <th>Field</th> <th>Value</th> </tr> </thead> <tbody>
<tr> <td>Primary Action</td> <td>unknown</td> </tr>
<tr> <td>Confidence</td> <td>0.0</td> </tr>
<tr> <td>Certainty</td> <td>unknown</td> </tr>
<tr> <td>Decompose Clauses</td> <td>1</td> </tr>
<tr> <td>SigilMediator Bindings</td> <td>2</td> </tr>
<tr> <td>SigilMediator Kinds</td> <td>[:math]</td> </tr>
<tr> <td>MutualIncompleteness</td> <td>no</td> </tr>
<tr> <td>Math Result</td> <td>2 plus 2 equals 4</td> </tr>
</tbody></table>
<p><strong>Result:</strong> ✅ PASS</p>
<ul>
 <li>✅ Clause count</li>
 <li>✅ Math routing</li>
</ul>
</details>
<p><br></p>
<hr>
<h2>Test — simple_knowledge</h2>
<p><strong>Input:</strong> <code>what is the capital of France</code></p>
<blockquote> <p>[Metaphysical contemplation active] Thinking it through: Metaphysics learns actuality and existence. (from the math cave) [Directives: What is quantum mechanics; Explain DNA; How does AI work; What is ethics; Tell me about ecosystems; Describe evolution; How does arithmetic work; What is algebra; Calculus is hard]</p> </blockquote>
<p><br></p>
<details> <summary><strong>📊 Telemetry — click to expand</strong></summary>
 <table class="e-rte-table"> <thead> <tr> <th>Field</th> <th>Value</th> </tr> </thead> <tbody>
<tr> <td>Primary Action</td> <td>ponder</td> </tr>
<tr> <td>Confidence</td> <td>0.53</td> </tr>
<tr> <td>Certainty</td> <td>SURE</td> </tr>
<tr> <td>Decompose Clauses</td> <td>1</td> </tr>
<tr> <td>SigilMediator Bindings</td> <td>0</td> </tr>
<tr> <td>SigilMediator Kinds</td> <td>Symbol[]</td> </tr>
<tr> <td>MutualIncompleteness</td> <td>no</td> </tr>
</tbody></table>
<p><strong>Lobe Orchestration:</strong> Floor winner: philosophy (avg_conf=0.528, topicality=0.0, curved=0.528, votes=1) | Secondaries: none | Tie coinflip: false | MutualIncompleteness: no</p>
<p><strong>Result:</strong> ✅ PASS</p>
<ul>
 <li>✅ Clause count</li>
 <li>✅ Response coherence</li>
</ul>
</details>
<p><br></p>
<hr>
<h2>Test — multipart_arith_knowledge</h2>
<p><strong>Input:</strong> <code>what is 3 times 4 and what is the sky</code></p>
<blockquote> <p>[Plain-language specialist active] 3 times 4 equals 12. [Compression specialist active] Compressed summaries surface the core point.</p> </blockquote>
<p><br></p>
<details> <summary><strong>📊 Telemetry — click to expand</strong></summary>
 <table class="e-rte-table"> <thead> <tr> <th>Field</th> <th>Value</th> </tr> </thead> <tbody>
<tr> <td>Primary Action</td> <td>clarify</td> </tr>
<tr> <td>Confidence</td> <td>0.63</td> </tr>
<tr> <td>Certainty</td> <td>SURE</td> </tr>
<tr> <td>Decompose Clauses</td> <td>2</td> </tr>
<tr> <td>SigilMediator Bindings</td> <td>0</td> </tr>
<tr> <td>SigilMediator Kinds</td> <td>Symbol[]</td> </tr>
<tr> <td>MutualIncompleteness</td> <td>YES coequal=philosophy,science,technology</td> </tr>
<tr> <td>Coequal Lobe IDs</td> <td>philosophy,science,technology</td> </tr>
<tr> <td>Math Result</td> <td>3 times 4 equals 12</td> </tr>
</tbody></table>
<p><strong>Lobe Orchestration:</strong> Floor winner: philosophy (avg_conf=0.661, topicality=0.0, curved=0.661, votes=3) | Secondaries: technology | Tie coinflip: false | MutualIncompleteness: YES coequal=philosophy,science,technology</p>
<p><strong>Decomposition:</strong> 2 clause(s) → <code>"what is 3 times 4", "what is the sky"</code></p>
<p><strong>Result:</strong> ✅ PASS</p>
<ul>
 <li>✅ Clause count</li>
 <li>✅ Math routing</li>
 <li>✅ Multipart routing</li>
 <li>✅ No arithmetic bleed</li>
 <li>✅ Mutual incompleteness fired</li>
 <li>✅ Response coherence</li>
</ul>
</details>
<p><br></p>
<hr>
<h2>Test — multipart_arith_emotion</h2>
<p><strong>Input:</strong> <code>what is 5 minus 1 but how are you feeling</code></p>
<blockquote> <p>[Engineering reasoning active] 5 minus 1 equals 4.</p> </blockquote>
<p><br></p>
<details> <summary><strong>📊 Telemetry — click to expand</strong></summary>
 <table class="e-rte-table"> <thead> <tr> <th>Field</th> <th>Value</th> </tr> </thead> <tbody>
<tr> <td>Primary Action</td> <td>unknown</td> </tr>
<tr> <td>Confidence</td> <td>0.0</td> </tr>
<tr> <td>Certainty</td> <td>unknown</td> </tr>
<tr> <td>Decompose Clauses</td> <td>2</td> </tr>
<tr> <td>SigilMediator Bindings</td> <td>0</td> </tr>
<tr> <td>SigilMediator Kinds</td> <td>Symbol[]</td> </tr>
<tr> <td>MutualIncompleteness</td> <td>YES coequal=math,philosophy,technology</td> </tr>
<tr> <td>Coequal Lobe IDs</td> <td>math,philosophy,technology</td> </tr>
<tr> <td>Math Result</td> <td>5 minus 1 equals 4</td> </tr>
</tbody></table>
<p><strong>Lobe Orchestration:</strong> Floor winner: technology (avg_conf=0.649, topicality=0.0, curved=0.649, votes=2) | Secondaries: none | Tie coinflip: false | MutualIncompleteness: YES coequal=math,philosophy,technology</p>
<p><strong>Decomposition:</strong> 2 clause(s) → <code>"what is 5 minus 1", "how are you feeling"</code></p>
<p><strong>Result:</strong> ✅ PASS</p>
<ul>
 <li>✅ Clause count</li>
 <li>✅ Math routing</li>
 <li>✅ Multipart routing</li>
 <li>✅ No arithmetic bleed</li>
 <li>✅ Mutual incompleteness fired</li>
</ul>
</details>
<p><br></p>
<hr>
<h2>Test — three_part_compound</h2>
<p><strong>Input:</strong> <code>what is 6 plus 1 and what is water also what is love</code></p>
<blockquote> <p>[Engineering reasoning active] 6 plus 1 equals 7.</p> </blockquote>
<p><br></p>
<details> <summary><strong>📊 Telemetry — click to expand</strong></summary>
 <table class="e-rte-table"> <thead> <tr> <th>Field</th> <th>Value</th> </tr> </thead> <tbody>
<tr> <td>Primary Action</td> <td>unknown</td> </tr>
<tr> <td>Confidence</td> <td>0.0</td> </tr>
<tr> <td>Certainty</td> <td>unknown</td> </tr>
<tr> <td>Decompose Clauses</td> <td>3</td> </tr>
<tr> <td>SigilMediator Bindings</td> <td>0</td> </tr>
<tr> <td>SigilMediator Kinds</td> <td>Symbol[]</td> </tr>
<tr> <td>MutualIncompleteness</td> <td>YES coequal=math,philosophy,technology,science</td> </tr>
<tr> <td>Coequal Lobe IDs</td> <td>math,philosophy,technology,science</td> </tr>
<tr> <td>Math Result</td> <td>6 plus 1 equals 7</td> </tr>
</tbody></table>
<p><strong>Lobe Orchestration:</strong> Floor winner: technology (avg_conf=0.94, topicality=0.0, curved=0.94, votes=2) | Secondaries: philosophy | Tie coinflip: false | MutualIncompleteness: YES coequal=math,philosophy,technology,science</p>
<p><strong>Decomposition:</strong> 3 clause(s) → <code>"what is 6 plus 1", "what is water", "what is love"</code></p>
<p><strong>Result:</strong> ✅ PASS</p>
<ul>
 <li>✅ Clause count</li>
 <li>✅ Math routing</li>
 <li>✅ Multipart routing</li>
 <li>✅ No arithmetic bleed</li>
 <li>✅ Mutual incompleteness fired</li>
</ul>
</details>
<p><br></p>
<hr>
<h2>Test — single_clause_control</h2>
<p><strong>Input:</strong> <code>tell me about fire</code></p>
<blockquote> <p>[no scaffold found]</p> </blockquote>
<p><br></p>
<details> <summary><strong>📊 Telemetry — click to expand</strong></summary>
 <table class="e-rte-table"> <thead> <tr> <th>Field</th> <th>Value</th> </tr> </thead> <tbody>
<tr> <td>Primary Action</td> <td>unknown</td> </tr>
<tr> <td>Confidence</td> <td>0.0</td> </tr>
<tr> <td>Certainty</td> <td>unknown</td> </tr>
<tr> <td>Decompose Clauses</td> <td>1</td> </tr>
<tr> <td>SigilMediator Bindings</td> <td>0</td> </tr>
<tr> <td>SigilMediator Kinds</td> <td>Symbol[]</td> </tr>
<tr> <td>MutualIncompleteness</td> <td>no</td> </tr>
</tbody></table>
<p><strong>Result:</strong> ✅ PASS</p>
<ul>
 <li>✅ Clause count</li>
</ul>
</details>
<p><br></p>
<hr>
<h2>Test — multipart_or_split</h2>
<p><strong>Input:</strong> <code>what is 8 divided by 2 or what is the ocean</code></p>
<blockquote> <p>[Biological reasoning engine active] 8 divided by 2 equals 4.</p> </blockquote>
<p><br></p>
<details> <summary><strong>📊 Telemetry — click to expand</strong></summary>
 <table class="e-rte-table"> <thead> <tr> <th>Field</th> <th>Value</th> </tr> </thead> <tbody>
<tr> <td>Primary Action</td> <td>unknown</td> </tr>
<tr> <td>Confidence</td> <td>0.0</td> </tr>
<tr> <td>Certainty</td> <td>unknown</td> </tr>
<tr> <td>Decompose Clauses</td> <td>2</td> </tr>
<tr> <td>SigilMediator Bindings</td> <td>0</td> </tr>
<tr> <td>SigilMediator Kinds</td> <td>Symbol[]</td> </tr>
<tr> <td>MutualIncompleteness</td> <td>YES coequal=philosophy,science,technology</td> </tr>
<tr> <td>Coequal Lobe IDs</td> <td>philosophy,science,technology</td> </tr>
<tr> <td>Math Result</td> <td>8 divided by 2 equals 4</td> </tr>
</tbody></table>
<p><strong>Lobe Orchestration:</strong> Floor winner: science (avg_conf=0.917, topicality=0.0, curved=0.917, votes=2) | Secondaries: philosophy | Tie coinflip: false | MutualIncompleteness: YES coequal=philosophy,science,technology</p>
<p><strong>Decomposition:</strong> 2 clause(s) → <code>"what is 8 divided by 2", "what is the ocean"</code></p>
<p><strong>Result:</strong> ✅ PASS</p>
<ul>
 <li>✅ Clause count</li>
 <li>✅ Math routing</li>
 <li>✅ Multipart routing</li>
 <li>✅ No arithmetic bleed</li>
 <li>✅ Mutual incompleteness fired</li>
</ul>
</details>
<p><br></p>
<hr>
<h2>Test — multipart_arith_compare</h2>
<p><strong>Input:</strong> <code>what is 2 plus 3 and what is 4 times 5</code></p>
<blockquote> <p>[Engineering reasoning active] 2 plus 3 = 5, then 3 times 4 = 20, so the answer is 20; 2 plus 3 equals 5; 4 times 5 equals 20.</p> </blockquote>
<p><br></p>
<details> <summary><strong>📊 Telemetry — click to expand</strong></summary>
 <table class="e-rte-table"> <thead> <tr> <th>Field</th> <th>Value</th> </tr> </thead> <tbody>
<tr> <td>Primary Action</td> <td>unknown</td> </tr>
<tr> <td>Confidence</td> <td>0.0</td> </tr>
<tr> <td>Certainty</td> <td>unknown</td> </tr>
<tr> <td>Decompose Clauses</td> <td>2</td> </tr>
<tr> <td>SigilMediator Bindings</td> <td>0</td> </tr>
<tr> <td>SigilMediator Kinds</td> <td>Symbol[]</td> </tr>
<tr> <td>MutualIncompleteness</td> <td>YES coequal=science,technology</td> </tr>
<tr> <td>Coequal Lobe IDs</td> <td>science,technology</td> </tr>
<tr> <td>Math Result</td> <td>2 plus 3 equals 5</td> </tr>
</tbody></table>
<p><strong>Lobe Orchestration:</strong> Floor winner: science (avg_conf=0.663, topicality=0.0, curved=0.663, votes=1) | Secondaries: none | Tie coinflip: false | MutualIncompleteness: YES coequal=science,technology</p>
<p><strong>Decomposition:</strong> 2 clause(s) → <code>"what is 2 plus 3", "what is 4 times 5"</code></p>
<p><strong>Result:</strong> ✅ PASS</p>
<ul>
 <li>✅ Clause count</li>
 <li>✅ Math routing</li>
 <li>✅ Multipart routing</li>
 <li>✅ No arithmetic bleed</li>
 <li>✅ Mutual incompleteness fired</li>
</ul>
</details>
<p><br></p>
<hr>
<h2>Test — multipart_philosophy_science</h2>
<p><strong>Input:</strong> <code>what is consciousness and what is photosynthesis</code></p>
<blockquote> <p>[Engineering reasoning active] Here is the picture: Computers perform automated tasks. (from the math cave) [Directives: What is quantum mechanics; Explain DNA; How does AI work; What is ethics; Tell me about ecosystems; Calculus is hard]</p> </blockquote>
<p><br></p>
<details> <summary><strong>📊 Telemetry — click to expand</strong></summary>
 <table class="e-rte-table"> <thead> <tr> <th>Field</th> <th>Value</th> </tr> </thead> <tbody>
<tr> <td>Primary Action</td> <td>describe</td> </tr>
<tr> <td>Confidence</td> <td>0.64</td> </tr>
<tr> <td>Certainty</td> <td>SURE</td> </tr>
<tr> <td>Decompose Clauses</td> <td>2</td> </tr>
<tr> <td>SigilMediator Bindings</td> <td>0</td> </tr>
<tr> <td>SigilMediator Kinds</td> <td>Symbol[]</td> </tr>
<tr> <td>MutualIncompleteness</td> <td>no</td> </tr>
</tbody></table>
<p><strong>Lobe Orchestration:</strong> Floor winner: technology (avg_conf=0.639, topicality=0.0, curved=0.639, votes=1) | Secondaries: none | Tie coinflip: false | MutualIncompleteness: no</p>
<p><strong>Decomposition:</strong> 2 clause(s) → <code>"what is consciousness", "what is photosynthesis"</code></p>
<p><strong>Result:</strong> ✅ PASS</p>
<ul>
 <li>✅ Clause count</li>
 <li>✅ Multipart routing</li>
 <li>✅ Response coherence</li>
</ul>
</details>
<p><br></p>
<hr>
<h2>Test — multipart_tech_nature</h2>
<p><strong>Input:</strong> <code>how does AI work and what are ecosystems</code></p>
<blockquote> <p>[Evolutionary reasoning active] Here is the picture: Evolution shapes species over time. (from the math cave) [Directives: What is quantum mechanics; How does AI work; What is ethics; Tell me about ecosystems; Describe evolution; How does arithmetic work; What is algebra]</p> </blockquote>
<p><br></p>
<details> <summary><strong>📊 Telemetry — click to expand</strong></summary>
 <table class="e-rte-table"> <thead> <tr> <th>Field</th> <th>Value</th> </tr> </thead> <tbody>
<tr> <td>Primary Action</td> <td>describe</td> </tr>
<tr> <td>Confidence</td> <td>0.48</td> </tr>
<tr> <td>Certainty</td> <td>SURE</td> </tr>
<tr> <td>Decompose Clauses</td> <td>2</td> </tr>
<tr> <td>SigilMediator Bindings</td> <td>0</td> </tr>
<tr> <td>SigilMediator Kinds</td> <td>Symbol[]</td> </tr>
<tr> <td>MutualIncompleteness</td> <td>no</td> </tr>
</tbody></table>
<p><strong>Decomposition:</strong> 2 clause(s) → <code>"how does AI work", "what are ecosystems"</code></p>
<p><strong>Result:</strong> ✅ PASS</p>
<ul>
 <li>✅ Clause count</li>
 <li>✅ Multipart routing</li>
 <li>✅ Response coherence</li>
</ul>
</details>
<p><br></p>
<hr>
<h2>Summary</h2>
<table class="e-rte-table"> <thead> <tr> <th>#</th> <th>Test</th> <th>Input</th> <th>Math</th> <th>Clauses</th> <th>MutualInc</th> <th>Result</th> </tr> </thead> <tbody>
<tr> <td>1</td> <td>simple_arithmetic</td> <td><code>what is 2 plus 2</code></td> <td>2 plus 2 equals 4</td> <td>1</td> <td>no</td> <td>✅ PASS</td> </tr>
<tr> <td>2</td> <td>simple_knowledge</td> <td><code>what is the capital of France</code></td> <td>—</td> <td>1</td> <td>no</td> <td>✅ PASS</td> </tr>
<tr> <td>3</td> <td>multipart_arith_knowledge</td> <td><code>what is 3 times 4 and what is the sky</code></td> <td>3 times 4 equals 12</td> <td>2</td> <td>YES coequal=philosophy,science,technology</td> <td>✅ PASS</td> </tr>
<tr> <td>4</td> <td>multipart_arith_emotion</td> <td><code>what is 5 minus 1 but how are you feeling</code></td> <td>5 minus 1 equals 4</td> <td>2</td> <td>YES coequal=math,philosophy,technology</td> <td>✅ PASS</td> </tr>
<tr> <td>5</td> <td>three_part_compound</td> <td><code>what is 6 plus 1 and what is water also what is love</code></td> <td>6 plus 1 equals 7</td> <td>3</td> <td>YES coequal=math,philosophy,technology,science</td> <td>✅ PASS</td> </tr>
<tr> <td>6</td> <td>single_clause_control</td> <td><code>tell me about fire</code></td> <td>—</td> <td>1</td> <td>no</td> <td>✅ PASS</td> </tr>
<tr> <td>7</td> <td>multipart_or_split</td> <td><code>what is 8 divided by 2 or what is the ocean</code></td> <td>8 divided by 2 equals 4</td> <td>2</td> <td>YES coequal=philosophy,science,technology</td> <td>✅ PASS</td> </tr>
<tr> <td>8</td> <td>multipart_arith_compare</td> <td><code>what is 2 plus 3 and what is 4 times 5</code></td> <td>2 plus 3 equals 5</td> <td>2</td> <td>YES coequal=science,technology</td> <td>✅ PASS</td> </tr>
<tr> <td>9</td> <td>multipart_philosophy_science</td> <td><code>what is consciousness and what is photosynthesis</code></td> <td>—</td> <td>2</td> <td>no</td> <td>✅ PASS</td> </tr>
<tr> <td>10</td> <td>multipart_tech_nature</td> <td><code>how does AI work and what are ecosystems</code></td> <td>—</td> <td>2</td> <td>no</td> <td>✅ PASS</td> </tr>
</tbody></table>
<p><strong>Tests passed:</strong> 10 / 10</p>
<h3>v7.29 Features Verified</h3>
<ol>
 <li><strong>Deferred clearing</strong> — finally block wraps ENTIRE rendering section (primary + math injection + multipart), shared state survives until ALL per-lobe rendering is complete</li>
 <li><strong>Per-group band re-write</strong> — before each non-primary COMMANDS call, band assignments (top/support/hedge), lockin promotion, and relation scores are re-computed for THAT group's votes and written into shared temp list</li>
 <li><strong>No ghost :unknown bands</strong> — band_of() returns correct band for non-primary votes (was returning :unknown after premature finally clear)</li>
 <li><strong>Proper sure/unsure splits for non-primary groups</strong> — COMMANDS receives correct sure/unsure vote arrays instead of all-as-unsure</li>
 <li><strong>Mutual incompleteness detection</strong> — 2+ lobes with ≥1 lock-in each get co-equal standing (v7.28 carry-forward)</li>
 <li><strong>Coequal vote bucketing</strong> — all coequal lobe votes go into winner bucket, no secondary demotion (v7.28 carry-forward)</li>
 <li><strong>curved_avg speaking order</strong> — floor winner still speaks first among coequals (v7.28 carry-forward)</li>
 <li><strong>Multipart decomposition</strong> — compound inputs split into clauses with per-clause objective IDs (v7.28 carry-forward)</li>
 <li><strong>Sigil routing</strong> — math sigils inject nodes with guaranteed confidence floor (v7.28 carry-forward)</li>
</ol>
<p><strong>✅ ALL TESTS PASSED — v7.29 Deferred Clearing + Per-Group Band Re-Write verified.</strong></p>