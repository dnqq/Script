document.addEventListener('DOMContentLoaded', () => {
  const scriptListContainer = document.getElementById('script-list');

  fetch('/manifest.json')
    .then(response => response.json())
    .then(scripts => {
      if (scripts.length === 0) {
        scriptListContainer.innerHTML = '<p class="text-center col-span-full">暂无脚本</p>';
        return;
      }

      // 按类别对脚本进行分组
      const groupedScripts = scripts.reduce((acc, script) => {
        const category = script.category || 'Other';
        if (!acc[category]) {
          acc[category] = [];
        }
        acc[category].push(script);
        return acc;
      }, {});

      // 清空容器
      scriptListContainer.innerHTML = '';

      // 遍历每个类别并渲染
      for (const category in groupedScripts) {
        const categorySection = document.createElement('div');
        categorySection.className = 'col-span-full mb-12';
        
        const categoryTitle = document.createElement('h2');
        categoryTitle.className = 'text-3xl font-bold border-b-2 border-gray-700 pb-2 mb-6';
        categoryTitle.textContent = category;
        categorySection.appendChild(categoryTitle);

        const grid = document.createElement('div');
        grid.className = 'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6';

        groupedScripts[category].forEach(script => {
          const scriptCard = `
            <div class="bg-gray-800 rounded-lg shadow-lg p-6 flex flex-col">
              <h3 class="text-xl font-bold mb-2 flex-grow">${script.name}</h3>
              <p class="text-gray-400 mb-4">下载次数: ${script.downloads}</p>
              <a href="${script.url}" class="inline-block bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded text-center" download>
                下载
              </a>
            </div>
          `;
          grid.innerHTML += scriptCard;
        });

        categorySection.appendChild(grid);
        scriptListContainer.appendChild(categorySection);
      }
    })
    .catch(error => {
      console.error('获取脚本列表失败:', error);
      scriptListContainer.innerHTML = '<p class="text-center col-span-full text-red-500">加载脚本列表失败，请稍后重试。</p>';
    });
});