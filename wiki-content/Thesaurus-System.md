# Thesaurus System

The Thesaurus (`src/Thesaurus.jl`) provides dimensional similarity analysis and synonym expansion.

## Similarity Comparison

```
/thesaurus word1 | word2
```

Returns five dimensions:
- **Overall %** — aggregate similarity
- **Semantic %** — meaning overlap
- **Contextual %** — usage context similarity
- **Associative %** — conceptual association
- **Confidence %** — reliability of the comparison

### With Context

```
/thesaurus word1 | word2 :: context1,context2 :: context3,context4
```

Context lists modulate scoring — useful for disambiguating words with multiple meanings.

## Synonym Seeds

The system ships with a hardcoded seed dictionary. Runtime additions via `/addSynonym` are merged on top:

```
/addSynonym causes triggers
```

This normalizes "triggers" → "causes" before triple extraction.

## Negative Thesaurus (Inhibition)

The inhibition filter suppresses words before they enter the scan:

```
/negativeThesaurus add badword --reason "Noise term that triggers false positives"
/negativeThesaurus list
/negativeThesaurus remove badword
/negativeThesaurus flush
```

Inhibited words are filtered from input before PatternScanner runs. This shapes what the specimen sees.

## Purpose

The thesaurus helps the system operate on **concept neighborhoods** rather than only exact string identity. This improves recall, semantic latching, and route flexibility.
