<script lang="ts">
    interface WaterUsageData {
      totalRequired: number;
      userContribution: number;
      otherUserContribution: {
        user: string;
        amount: number;
      }[];
      cityContribution: number;
      naturalContribution: number;
    }
    
    const waterData: WaterUsageData = {
      totalRequired: 700,
      userContribution: 120,
      otherUserContribution: [
        { user: 'user123', amount: 30 }
      ],
      cityContribution: 50,
      naturalContribution: 100
    };
    
    const missingAmount = waterData.totalRequired - (
      waterData.userContribution + 
      waterData.otherUserContribution.reduce((acc, curr) => acc + curr.amount, 0) + 
      waterData.cityContribution + 
      waterData.naturalContribution
    );
    </script>
    
    <section class="flex relative flex-col items-start text-lg text-black max-w-[350px]">
      <header class="flex z-0 gap-10 items-start self-stretch w-full whitespace-nowrap">
        <p class="font-black text-right"></p>
      </header>
    
      <article class="flex z-0 flex-col mt-3.5 max-w-full w-[249px]">
        <header class="flex gap-3 items-center w-full font-bold">
          <img
            loading="lazy"
            src="https://cdn.builder.io/api/v1/image/assets/TEMP/43ef0bd6b3bcd987f35a760348df2929b255c20b15e4cae2b9914fe13ded19c7?placeholderIfAbsent=true&apiKey=b8f28e7fcb9f4cfa8e5ca30024a27884"
            alt="Water usage statistics icon"
            class="object-contain shrink-0 self-stretch my-auto w-6 aspect-square"
          />
          <h2 class="self-stretch my-auto">Letzte 30 Tage</h2>
        </header>
    
        <section class="flex relative flex-col mt-4 w-full min-h-[348px]">
          <div
            class="flex absolute top-0 left-0 z-0 bg-red-100 h-[330px] min-h-[330px] rounded-[50px] w-[33px]"
            role="presentation"
></div>
          
          <div class="flex z-0 flex-1 gap-3 items-center size-full">
            <div
              class="flex shrink-0 self-stretch h-[94px] rounded-[30px] w-[33px]"
              role="presentation"
></div>
            <div
              class="shrink-0 self-stretch my-auto h-0 border border-solid border-black border-opacity-40 w-[29px]"
              role="presentation"
></div>
            <p class="self-stretch my-auto">{missingAmount} Liter fehlen</p>
          </div>
    
          <div class="flex z-0 gap-3 items-center w-full min-h-[94px]">
            <div
              class="flex shrink-0 self-stretch bg-emerald-400 h-[94px] rounded-[30px] w-[33px]"
              role="presentation"
></div>
            <div
              class="shrink-0 self-stretch my-auto h-0 border border-solid border-black border-opacity-40 w-[29px]"
              role="presentation"
></div>
            <p class="self-stretch my-auto">{waterData.userContribution} Liter von Dir</p>
          </div>
    
          {#each waterData.otherUserContribution as contribution}
            <div class="flex z-0 gap-3 items-center w-full min-h-[41px]">
              <div
                class="flex shrink-0 self-stretch bg-slate-500 h-[41px] rounded-[30px] w-[33px]"
                role="presentation"
></div>
              <div
                class="shrink-0 self-stretch my-auto h-0 border border-solid border-black border-opacity-40 w-[29px]"
                role="presentation"
></div>
              <p class="self-stretch my-auto">{contribution.amount} Liter von {contribution.user}</p>
            </div>
          {/each}
    
          <div class="flex z-0 gap-3 items-center w-full min-h-[53px]">
            <div
              class="flex shrink-0 self-stretch bg-slate-500 h-[53px] rounded-[30px] w-[33px]"
              role="presentation"
></div>
            <div
              class="shrink-0 self-stretch my-auto h-0 border border-solid border-black border-opacity-40 w-[29px]"
              role="presentation"
></div>
            <p class="self-stretch my-auto">{waterData.cityContribution} Liter von Stadt</p>
          </div>
    
          <div class="flex z-0 gap-3 items-center w-full min-h-[66px]">
            <div
              class="flex shrink-0 self-stretch bg-slate-400 h-[66px] rounded-[30px] w-[33px]"
              role="presentation"
></div>
            <div
              class="shrink-0 self-stretch my-auto h-0 border border-solid border-black border-opacity-40 w-[29px]"
              role="presentation"
></div>
            <p class="self-stretch my-auto">{waterData.naturalContribution} Liter von Natur</p>
          </div>
        </section>
      </article>
    
      <div
        class="absolute z-0 h-0 border border-solid border-black border-opacity-10 bottom-[-19px] min-h-[1px] right-[-3px] w-[353px]"
        role="presentation"
></div>
    </section>