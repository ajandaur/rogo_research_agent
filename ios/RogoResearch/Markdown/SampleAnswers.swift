#if DEBUG
/// Real agent answers, captured from the server's SSE stream, for previews and tests.
enum SampleAnswers {
    /// "Is GLBX a better business than ITCH?" (text_delta events joined).
    static let glbxVsItch = """
    No — on underlying business quality, Initech (ITCH) looks like the better business, even though Globex (GLBX) is far larger. It depends on what "better" means to you, but here's the comparison.

    ### Headline financials (FY2024, latest comparable year)

    | Metric | GLBX | ITCH |
    |---|---|---|
    | Revenue | $8.72B | $988M |
    | Revenue growth (FY21–24 CAGR) | ~1.2% | ~15.6% |
    | Gross margin | 30.4% | 74.8% |
    | Operating margin | 9.6% | 17.5% |
    | Net margin | 7.1% | 13.0% |
    | FCF margin | 5.9% | 10.7% |

    ### Why ITCH wins on quality
    - **Margins are structurally much higher** — software gross margins (~75%) vs. industrial conglomerate margins (~30%) reflect fundamentally better unit economics.
    - **Growing faster** — ~15%+ revenue CAGR vs. GLBX's roughly flat/low-single-digit growth (GLBX revenue was actually down in FY2023).
    - **Business model is shifting toward recurring revenue** — subscription is already 62% of ITCH's mix, which should keep improving margins and visibility as the perpetual-license book runs off.
    - **More capital-efficient** — FCF conversion (FCF/net income) and FCF margin are both notably better at ITCH.

    ### Why GLBX still has points in its favor
    - **Scale and diversification** — three largely uncorrelated segments (energy equipment, building products, specialty chemicals) and ~50% international revenue reduce single-market risk.
    - **Absolute cash generation is bigger** — $536M FCF in FY2025 vs. ITCH's ~$106M (FY2024), useful for dividends, M&A, or buybacks.
    - **More durable/less disruptable** — industrial equipment and building products are harder to displace than enterprise software, where competitive and technology risk (including from AI-native entrants) is arguably higher.

    ### Bottom line
    If "better business" means margin structure, growth, and capital efficiency, ITCH is clearly superior. If it means scale, diversification, and absolute free cash flow, GLBX wins. One caveat: ITCH's FY2025 numbers aren't filed yet (only preliminary 8-K guidance), so its growth/margin trajectory should be confirmed once the 10-K lands.
    """
}
#endif
