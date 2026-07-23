# test_input_queue.jl
# ==============================================================================
# GRUG TEST: InputQueue + NegativeThesaurus — comprehensive unit tests.
# GRUG say: test the queue like testing cave door. Push, pop, overflow, inhibit.
# ==============================================================================

include("InputQueue.jl")
using .InputQueue
using Test

println("\n" * "="^60)
println("GRUG INPUT QUEUE + NEGATIVE THESAURUS TEST SUITE")
println("="^60)

# ==============================================================================
# HELPERS — GRUG reset state between test groups
# ==============================================================================

function reset_queue!()
    # GRUG: Drain everything so each test group starts clean
    while InputQueue.queue_size() > 0
        InputQueue.dequeue!()
    end
end

function reset_neg_thesaurus!()
    # GRUG: Remove all inhibitions so each group starts clean
    for entry in InputQueue.list_inhibitions()
        InputQueue.remove_inhibition!(entry.word)
    end
end

function reset_all!()
    reset_queue!()
    reset_neg_thesaurus!()
end

# ==============================================================================
# 1. QUEUE — Basic enqueue / dequeue / FIFO order
# ==============================================================================
@testset "InputQueue - Basic FIFO" begin
    reset_all!()

    # Empty queue dequeue returns nothing
    @test InputQueue.dequeue!() === nothing
    @test InputQueue.queue_size() == 0

    # Enqueue 3 items
    InputQueue.enqueue!("first")
    InputQueue.enqueue!("second")
    InputQueue.enqueue!("third")
    @test InputQueue.queue_size() == 3

    # Dequeue in FIFO order (all same priority = 0)
    e1 = InputQueue.dequeue!()
    @test e1 !== nothing
    @test e1.text == "first"
    @test e1.priority == 0

    e2 = InputQueue.dequeue!()
    @test e2.text == "second"

    e3 = InputQueue.dequeue!()
    @test e3.text == "third"

    @test InputQueue.dequeue!() === nothing
    @test InputQueue.queue_size() == 0

    println("  ✓ [1] Basic FIFO order verified")
end

# ==============================================================================
# 2. QUEUE — Priority ordering
# ==============================================================================
@testset "InputQueue - Priority Ordering" begin
    reset_all!()

    # Enqueue with mixed priorities
    InputQueue.enqueue!("low priority"; priority=0)
    InputQueue.enqueue!("high priority"; priority=10)
    InputQueue.enqueue!("medium priority"; priority=5)
    InputQueue.enqueue!("highest priority"; priority=99)

    @test InputQueue.queue_size() == 4

    # Should dequeue in priority order (highest first)
    e1 = InputQueue.dequeue!()
    @test e1.text == "highest priority"
    @test e1.priority == 99

    e2 = InputQueue.dequeue!()
    @test e2.text == "high priority"
    @test e2.priority == 10

    e3 = InputQueue.dequeue!()
    @test e3.text == "medium priority"
    @test e3.priority == 5

    e4 = InputQueue.dequeue!()
    @test e4.text == "low priority"
    @test e4.priority == 0

    println("  ✓ [2] Priority ordering verified (99 > 10 > 5 > 0)")
end

# ==============================================================================
# 3. QUEUE — Stable sort (same priority preserves insertion order)
# ==============================================================================
@testset "InputQueue - Stable Sort" begin
    reset_all!()

    InputQueue.enqueue!("alpha"; priority=5)
    InputQueue.enqueue!("bravo"; priority=5)
    InputQueue.enqueue!("charlie"; priority=5)

    e1 = InputQueue.dequeue!()
    e2 = InputQueue.dequeue!()
    e3 = InputQueue.dequeue!()

    @test e1.text == "alpha"
    @test e2.text == "bravo"
    @test e3.text == "charlie"

    println("  ✓ [3] Stable sort: equal-priority items preserve insertion order")
end

# ==============================================================================
# 4. QUEUE — peek_queue (non-destructive read)
# ==============================================================================
@testset "InputQueue - Peek" begin
    reset_all!()

    InputQueue.enqueue!("peek me")
    InputQueue.enqueue!("peek me too")

    snapshot = InputQueue.peek_queue()
    @test length(snapshot) == 2
    @test snapshot[1].text == "peek me"
    @test snapshot[2].text == "peek me too"

    # Peek should NOT remove items
    @test InputQueue.queue_size() == 2

    # Mutations to snapshot should not affect internal queue
    empty!(snapshot)
    @test InputQueue.queue_size() == 2

    println("  ✓ [4] peek_queue returns snapshot without draining")
end

# ==============================================================================
# 5. QUEUE — flush_queue! (wipe everything)
# ==============================================================================
@testset "InputQueue - Flush" begin
    reset_all!()

    for i in 1:10
        InputQueue.enqueue!("item $i")
    end
    @test InputQueue.queue_size() == 10

    dropped = InputQueue.flush_queue!()
    @test dropped == 10
    @test InputQueue.queue_size() == 0

    # Flush empty queue returns 0
    dropped2 = InputQueue.flush_queue!()
    @test dropped2 == 0

    println("  ✓ [5] flush_queue! clears all items, returns count")
end

# ==============================================================================
# 6. QUEUE — Error: empty text
# ==============================================================================
@testset "InputQueue - Reject Empty Text" begin
    reset_all!()

    @test_throws InputQueue.InputQueueError InputQueue.enqueue!("")
    @test_throws InputQueue.InputQueueError InputQueue.enqueue!("   ")
    @test_throws InputQueue.InputQueueError InputQueue.enqueue!("\t\n")

    # Queue should still be empty
    @test InputQueue.queue_size() == 0

    println("  ✓ [6] Empty/whitespace text correctly rejected")
end

# ==============================================================================
# 7. QUEUE — Error: overflow at QUEUE_MAX_SIZE
# ==============================================================================
@testset "InputQueue - Overflow Protection" begin
    reset_all!()

    # Fill to max
    for i in 1:InputQueue.QUEUE_MAX_SIZE
        InputQueue.enqueue!("item $i")
    end
    @test InputQueue.queue_size() == InputQueue.QUEUE_MAX_SIZE

    # Next enqueue should throw
    @test_throws InputQueue.InputQueueError InputQueue.enqueue!("overflow!")

    # Queue size should not exceed max
    @test InputQueue.queue_size() == InputQueue.QUEUE_MAX_SIZE

    # Drain one, then enqueue should work again
    InputQueue.dequeue!()
    @test InputQueue.queue_size() == InputQueue.QUEUE_MAX_SIZE - 1
    InputQueue.enqueue!("fits now")
    @test InputQueue.queue_size() == InputQueue.QUEUE_MAX_SIZE

    println("  ✓ [7] Overflow protection at QUEUE_MAX_SIZE=$(InputQueue.QUEUE_MAX_SIZE)")
end

# ==============================================================================
# 8. QUEUE — Timestamp tracking
# ==============================================================================
@testset "InputQueue - Timestamps" begin
    reset_all!()

    t_before = time()
    InputQueue.enqueue!("timestamped entry")
    t_after = time()

    entry = InputQueue.dequeue!()
    @test entry.enqueued_at >= t_before
    @test entry.enqueued_at <= t_after

    println("  ✓ [8] Enqueue timestamps are valid (between pre/post times)")
end

# ==============================================================================
# 9. NEGATIVE THESAURUS — Basic add / check / remove
# ==============================================================================
@testset "NegativeThesaurus - Basic CRUD" begin
    reset_all!()

    @test InputQueue.inhibition_count() == 0

    # Add inhibition
    InputQueue.add_inhibition!("spam"; reason="test filter")
    @test InputQueue.is_inhibited("spam") == true
    @test InputQueue.is_inhibited("SPAM") == true   # case-insensitive
    @test InputQueue.is_inhibited("  Spam  ") == true  # strip whitespace
    @test InputQueue.inhibition_count() == 1

    # Check non-inhibited word
    @test InputQueue.is_inhibited("hello") == false

    # Remove inhibition
    removed = InputQueue.remove_inhibition!("spam")
    @test removed == true
    @test InputQueue.is_inhibited("spam") == false
    @test InputQueue.inhibition_count() == 0

    # Remove non-existent returns false
    removed2 = InputQueue.remove_inhibition!("nonexistent")
    @test removed2 == false

    println("  ✓ [9] NegativeThesaurus basic add/check/remove works")
end

# ==============================================================================
# 10. NEGATIVE THESAURUS — Case insensitivity and whitespace normalization
# ==============================================================================
@testset "NegativeThesaurus - Normalization" begin
    reset_all!()

    InputQueue.add_inhibition!("  HELLO  "; reason="case test")
    @test InputQueue.is_inhibited("hello") == true
    @test InputQueue.is_inhibited("HELLO") == true
    @test InputQueue.is_inhibited("  Hello  ") == true

    # List should show lowercased/stripped version
    entries = InputQueue.list_inhibitions()
    @test length(entries) == 1
    @test entries[1].word == "hello"
    @test entries[1].reason == "case test"

    println("  ✓ [10] Case insensitivity and whitespace normalization verified")
end

# ==============================================================================
# 11. NEGATIVE THESAURUS — Duplicate rejection
# ==============================================================================
@testset "NegativeThesaurus - Duplicate Rejection" begin
    reset_all!()

    InputQueue.add_inhibition!("duplicate")
    @test_throws InputQueue.InputQueueError InputQueue.add_inhibition!("duplicate")
    @test_throws InputQueue.InputQueueError InputQueue.add_inhibition!("DUPLICATE")  # case-insensitive dup
    @test InputQueue.inhibition_count() == 1

    println("  ✓ [11] Duplicate inhibitions correctly rejected")
end

# ==============================================================================
# 12. NEGATIVE THESAURUS — Empty word rejection
# ==============================================================================
@testset "NegativeThesaurus - Reject Empty Word" begin
    reset_all!()

    @test_throws InputQueue.InputQueueError InputQueue.add_inhibition!("")
    @test_throws InputQueue.InputQueueError InputQueue.add_inhibition!("   ")
    @test InputQueue.inhibition_count() == 0

    println("  ✓ [12] Empty/whitespace inhibition words correctly rejected")
end

# ==============================================================================
# 13. NEGATIVE THESAURUS — Overflow protection
# ==============================================================================
@testset "NegativeThesaurus - Overflow Protection" begin
    reset_all!()

    # Fill to max
    for i in 1:InputQueue.NEG_THESAURUS_MAX
        InputQueue.add_inhibition!("word_$i")
    end
    @test InputQueue.inhibition_count() == InputQueue.NEG_THESAURUS_MAX

    # Next add should throw
    @test_throws InputQueue.InputQueueError InputQueue.add_inhibition!("overflow_word")
    @test InputQueue.inhibition_count() == InputQueue.NEG_THESAURUS_MAX

    println("  ✓ [13] NegativeThesaurus overflow at NEG_THESAURUS_MAX=$(InputQueue.NEG_THESAURUS_MAX)")
end

# ==============================================================================
# 14. NEGATIVE THESAURUS — apply_inhibition_filter (token list)
# ==============================================================================
@testset "NegativeThesaurus - Token Filter" begin
    reset_all!()

    InputQueue.add_inhibition!("bad")
    InputQueue.add_inhibition!("evil")
    InputQueue.add_inhibition!("toxic")

    tokens = ["hello", "bad", "world", "evil", "good", "toxic", "nice"]
    filtered = InputQueue.apply_inhibition_filter(tokens)

    @test "hello" in filtered
    @test "world" in filtered
    @test "good" in filtered
    @test "nice" in filtered
    @test !("bad" in filtered)
    @test !("evil" in filtered)
    @test !("toxic" in filtered)
    @test length(filtered) == 4

    # Empty token list should throw
    @test_throws InputQueue.InputQueueError InputQueue.apply_inhibition_filter(String[])

    println("  ✓ [14] Token filter removes inhibited words, keeps clean ones")
end

# ==============================================================================
# 15. NEGATIVE THESAURUS — apply_inhibition_to_text (full text pipeline)
# ==============================================================================
@testset "NegativeThesaurus - Text Filter" begin
    reset_all!()

    InputQueue.add_inhibition!("spam")
    InputQueue.add_inhibition!("junk")

    filtered_text, removed = InputQueue.apply_inhibition_to_text("hello spam world junk test")
    @test filtered_text == "hello world test"
    @test "spam" in removed
    @test "junk" in removed
    @test length(removed) == 2

    # Text with NO inhibited words passes through unchanged
    clean_text, removed2 = InputQueue.apply_inhibition_to_text("hello world test")
    @test clean_text == "hello world test"
    @test isempty(removed2)

    # Empty text should throw
    @test_throws InputQueue.InputQueueError InputQueue.apply_inhibition_to_text("")
    @test_throws InputQueue.InputQueueError InputQueue.apply_inhibition_to_text("   ")

    println("  ✓ [15] Text filter: removes inhibited tokens, returns filtered text + removed list")
end

# ==============================================================================
# 16. NEGATIVE THESAURUS — All tokens inhibited throws error
# ==============================================================================
@testset "NegativeThesaurus - All Tokens Inhibited" begin
    reset_all!()

    InputQueue.add_inhibition!("every")
    InputQueue.add_inhibition!("single")
    InputQueue.add_inhibition!("word")

    @test_throws InputQueue.InputQueueError InputQueue.apply_inhibition_to_text("every single word")

    println("  ✓ [16] All-tokens-inhibited correctly throws error (over-blocking detection)")
end

# ==============================================================================
# 17. NEGATIVE THESAURUS — list_inhibitions sorted alphabetically
# ==============================================================================
@testset "NegativeThesaurus - Sorted Listing" begin
    reset_all!()

    InputQueue.add_inhibition!("zebra")
    InputQueue.add_inhibition!("alpha")
    InputQueue.add_inhibition!("middle")

    entries = InputQueue.list_inhibitions()
    @test length(entries) == 3
    @test entries[1].word == "alpha"
    @test entries[2].word == "middle"
    @test entries[3].word == "zebra"

    println("  ✓ [17] list_inhibitions returns alphabetically sorted entries")
end

# ==============================================================================
# 18. INTEGRATION — Queue + NegativeThesaurus pipeline
# ==============================================================================
@testset "Integration - Queue + NegativeThesaurus Pipeline" begin
    reset_all!()

    # Set up inhibitions
    InputQueue.add_inhibition!("spam")
    InputQueue.add_inhibition!("noise")

    # Enqueue raw inputs
    InputQueue.enqueue!("hello spam world noise test")
    InputQueue.enqueue!("clean input no bad words here"; priority=5)
    InputQueue.enqueue!("noise at the beginning")

    # Process queue: dequeue then filter through NegativeThesaurus
    results = String[]
    while InputQueue.queue_size() > 0
        entry = InputQueue.dequeue!()
        filtered, _ = InputQueue.apply_inhibition_to_text(entry.text)
        push!(results, filtered)
    end

    # Priority item should come first
    @test results[1] == "clean input no bad words here"  # priority=5
    @test results[2] == "hello world test"  # spam & noise removed
    @test results[3] == "at the beginning"  # noise removed

    println("  ✓ [18] Integration: queue dequeue → inhibition filter pipeline works end-to-end")
end

# ==============================================================================
# 19. ERROR TYPE — InputQueueError has message and context
# ==============================================================================
@testset "InputQueueError - Error Structure" begin
    reset_all!()

    err = nothing
    try
        InputQueue.enqueue!("")
    catch e
        err = e
    end

    @test err !== nothing
    @test err isa InputQueue.InputQueueError
    @test !isempty(err.message)
    @test err.context == "enqueue!"

    println("  ✓ [19] InputQueueError carries message and context fields")
end

# ==============================================================================
# 20. STRESS — Rapid enqueue/dequeue cycle
# ==============================================================================
@testset "Stress - Rapid Enqueue/Dequeue" begin
    reset_all!()

    # Enqueue and dequeue 1000 items rapidly
    for i in 1:1000
        InputQueue.enqueue!("stress item $i")
        entry = InputQueue.dequeue!()
        @test entry.text == "stress item $i"
    end
    @test InputQueue.queue_size() == 0

    println("  ✓ [20] Stress test: 1000 rapid enqueue/dequeue cycles, queue clean after")
end

# ==============================================================================
# CLEANUP & SUMMARY
# ==============================================================================
reset_all!()

println("\n" * "="^60)
println("✅  ALL INPUT QUEUE + NEGATIVE THESAURUS TESTS PASSED")
println("="^60 * "\n")