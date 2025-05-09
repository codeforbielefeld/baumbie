<script lang="ts">
    export let water
    import {scaleLinear, scaleOrdinal} from "d3-scale";

    const order = ["missing", "thisUser", "users", "city", "rain"];
    water = water.sort((a: { source: string; amount: number }, b: { source: string; amount: number }) => {
        const indexA = order.indexOf(a.source);
        const indexB = order.indexOf(b.source);
        return (indexA === -1 ? order.length : indexA) - (indexB === -1 ? order.length : indexB);
    });

    let margin = {left:16};
    let annotationSizes = {margin:5, lineLengh:29};
    let columnSize = {width:15};
    let colWidth = 30;
    let colHeight = 300;
    let fontSize = 17;
    let lineHeight = 20.5;
    let chartWidth;
    const waterSum = water.reduce((sum: any, item: { amount: any; }) => sum + item.amount, 0);
 
    $: heightScale = scaleLinear()
			.domain([0, waterSum])
			.range([0, colHeight])

    const nameScale = scaleOrdinal<string, string>()
            .domain(["rain", "city", "users", "thisUser", "missing"])
            .range(["Regen", "von Stadt", "von BaumBIEs", "von Dir", "fehlen"]);

    const colorScale = scaleOrdinal<string, string>()
            .domain(["rain", "city", "users", "thisUser", "missing"])
            .range(["#7C99B2", "#5E7386", "#458E72", "#51AF8B", "#E20C1500"]);


    // Array to store the calculated heights and positions
    interface StackedElement {
        source: string;
        amount: number;
        height: number;
        y: number;
    }

    // Calculate heights and positions for the stacked chart
    $: stackedData = water.map((d: { source: string; amount: number }, index: number, arr: { source: string; amount: number }[]) => {
        const i = index;
        let height = heightScale(d.amount);
        let textPos = height;
        
        // Cumulative Height
        const y = index === 0 ? 0 : arr.slice(0, index).reduce((sum, prev) => sum + heightScale(prev.amount), 0);
        textPos = index === 0 ? 0 : arr.slice(0, index)
                                    .reduce((sum, prev) => y <= sum + i * lineHeight ? y - fontSize: y, 0);
        return {
            source: nameScale(d.source),
            color: colorScale(d.source),
            amount: d.amount,
            height: height,
            textPos: textPos,
            y: y
        };
        });

</script>

<p class="flex items-left ml-4 mt-4">
    <img src="/waterDrop.svg" class="mr-1"/><b>Letzte 30 Tage</b>
</p>
<div bind:clientWidth={chartWidth}>
    <svg width={chartWidth} height={colHeight}>
        <rect
        x="{margin.left}"
        y="0"
        fill="#E20C151A"
        width="{colWidth}"
        height="{colHeight}"
        rx="{columnSize.width}"
        ry="{columnSize.width}"
        />
        {#each stackedData as d}
            <rect
                x="{margin.left}"
                y="{d.y}"
                fill="{d.color}"
                width="{colWidth}"
                height="{d.height}"
                rx="{columnSize.width}"/>
            <line
                x1="{colWidth + margin.left + annotationSizes.margin}"
                y1="{d.y + d.height / 2 + lineHeight / 2}"
                x2="{colWidth + margin.left + annotationSizes.margin + annotationSizes.lineLengh}"
                y2="{d.y + d.height / 2 + lineHeight / 2}"
                stroke="#00000066"
                stroke-width="1"
            />
            <text
                x="{colWidth + margin.left + annotationSizes.margin*2 + annotationSizes.lineLengh}" 
                y="{d.y + d.height / 2 + lineHeight / 2}"
                fill="black"
                font-size="{fontSize}">
                {d.amount}l {d.source}
            </text>
        {/each}
    </svg>
</div>
