// Global variables
let currentStockData = null;
let currentChart = null;
let historicalData = [];
let currentTimeframe = '1M';

// API Configuration
const API_BASE_URL = 'https://query1.finance.yahoo.com/v8/finance/chart/';
const API_BASE_URL_QUOTE = 'https://query2.finance.yahoo.com/v10/finance/quoteSummary/';

// CORS Proxy for Yahoo Finance API (using a public proxy)
const CORS_PROXY = 'https://api.allorigins.win/raw?url=';

// Initialize the app
document.addEventListener('DOMContentLoaded', function() {
    // Add Enter key support for stock input
    document.getElementById('stockSymbol').addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
            searchStock();
        }
    });
    
    // Add input event to convert to uppercase
    document.getElementById('stockSymbol').addEventListener('input', function(e) {
        e.target.value = e.target.value.toUpperCase();
    });
});

// Main search function
async function searchStock() {
    const symbol = document.getElementById('stockSymbol').value.trim().toUpperCase();
    
    if (!symbol) {
        showError('Please enter a valid stock symbol');
        return;
    }
    
    showLoading(true);
    hideAllSections();
    
    try {
        // Fetch stock data
        const stockData = await fetchStockData(symbol);
        const historicalPrices = await fetchHistoricalData(symbol, currentTimeframe);
        
        // Store data globally
        currentStockData = stockData;
        historicalData = historicalPrices;
        
        // Display all sections
        displayStockSummary(stockData);
        displayPortfolioSection();
        displayChart(historicalPrices, symbol);
        displayTable(historicalPrices);
        
        showAllSections();
        
    } catch (error) {
        console.error('Error fetching stock data:', error);
        showError('Failed to fetch stock data. Please check the symbol and try again.');
    } finally {
        showLoading(false);
    }
}

// Fetch stock data from Yahoo Finance
async function fetchStockData(symbol) {
    try {
        // Try multiple approaches to get data
        const quoteUrl = `${CORS_PROXY}${encodeURIComponent(API_BASE_URL_QUOTE + symbol + '?modules=price,summaryDetail,defaultKeyStatistics')}`;
        const chartUrl = `${CORS_PROXY}${encodeURIComponent(API_BASE_URL + symbol + '?interval=1d&range=1d')}`;
        
        // Fetch quote data
        let quoteResponse;
        try {
            quoteResponse = await fetch(quoteUrl);
            if (!quoteResponse.ok) throw new Error('Quote API failed');
        } catch (error) {
            // Fallback to chart API only
            console.warn('Quote API failed, using chart API only');
        }
        
        // Fetch chart data
        const chartResponse = await fetch(chartUrl);
        if (!chartResponse.ok) throw new Error('Failed to fetch stock data');
        
        const chartData = await chartResponse.json();
        
        if (!chartData.chart || !chartData.chart.result || chartData.chart.result.length === 0) {
            throw new Error('Invalid stock symbol or no data available');
        }
        
        const result = chartData.chart.result[0];
        const meta = result.meta;
        const quote = result.indicators.quote[0];
        
        // Parse quote data if available
        let quoteData = null;
        if (quoteResponse && quoteResponse.ok) {
            try {
                quoteData = await quoteResponse.json();
            } catch (e) {
                console.warn('Failed to parse quote data');
            }
        }
        
        // Extract data
        const currentPrice = meta.regularMarketPrice || quote.close[quote.close.length - 1];
        const previousClose = meta.previousClose || quote.close[quote.close.length - 2] || currentPrice;
        const change = currentPrice - previousClose;
        const changePercent = (change / previousClose) * 100;
        
        // Build comprehensive stock data object
        const stockData = {
            symbol: meta.symbol,
            name: meta.longName || meta.symbol,
            price: currentPrice,
            change: change,
            changePercent: changePercent,
            previousClose: previousClose,
            marketCap: formatLargeNumber(meta.marketCap || getQuoteValue(quoteData, 'marketCap')),
            peRatio: getQuoteValue(quoteData, 'trailingPE') || 'N/A',
            high52w: formatPrice(meta.fiftyTwoWeekHigh || getQuoteValue(quoteData, 'fiftyTwoWeekHigh')),
            low52w: formatPrice(meta.fiftyTwoWeekLow || getQuoteValue(quoteData, 'fiftyTwoWeekLow')),
            volume: formatLargeNumber(meta.regularMarketVolume || quote.volume[quote.volume.length - 1]),
            avgVolume: formatLargeNumber(getQuoteValue(quoteData, 'averageVolume') || meta.averageVolume10days),
            currency: meta.currency || 'USD'
        };
        
        return stockData;
        
    } catch (error) {
        // Fallback to mock data for demonstration
        console.warn('Yahoo Finance API failed, using demo data');
        return getDemoStockData(symbol);
    }
}

// Helper function to get value from quote data
function getQuoteValue(quoteData, field) {
    if (!quoteData || !quoteData.quoteSummary || !quoteData.quoteSummary.result) return null;
    
    const modules = quoteData.quoteSummary.result[0];
    
    // Check in different modules
    for (const module of ['summaryDetail', 'defaultKeyStatistics', 'price']) {
        if (modules[module] && modules[module][field]) {
            const value = modules[module][field];
            return typeof value === 'object' ? value.raw : value;
        }
    }
    return null;
}

// Fetch historical data
async function fetchHistoricalData(symbol, timeframe) {
    try {
        const range = getTimeframeRange(timeframe);
        const url = `${CORS_PROXY}${encodeURIComponent(API_BASE_URL + symbol + `?interval=1d&range=${range}`)}`;
        
        const response = await fetch(url);
        if (!response.ok) throw new Error('Failed to fetch historical data');
        
        const data = await response.json();
        
        if (!data.chart || !data.chart.result || data.chart.result.length === 0) {
            throw new Error('No historical data available');
        }
        
        const result = data.chart.result[0];
        const timestamps = result.timestamp;
        const quote = result.indicators.quote[0];
        
        const historicalData = timestamps.map((timestamp, index) => ({
            date: new Date(timestamp * 1000),
            open: quote.open[index],
            high: quote.high[index],
            low: quote.low[index],
            close: quote.close[index],
            volume: quote.volume[index]
        })).filter(item => item.close !== null); // Filter out null values
        
        return historicalData;
        
    } catch (error) {
        console.warn('Failed to fetch historical data, using demo data');
        return getDemoHistoricalData(symbol, timeframe);
    }
}

// Get demo data for fallback
function getDemoStockData(symbol) {
    const basePrice = 150 + Math.random() * 100;
    const change = (Math.random() - 0.5) * 10;
    
    return {
        symbol: symbol,
        name: `${symbol} Corporation`,
        price: basePrice,
        change: change,
        changePercent: (change / basePrice) * 100,
        previousClose: basePrice - change,
        marketCap: '1.2T',
        peRatio: (15 + Math.random() * 20).toFixed(2),
        high52w: formatPrice(basePrice * 1.2),
        low52w: formatPrice(basePrice * 0.8),
        volume: '45.2M',
        avgVolume: '52.1M',
        currency: 'USD'
    };
}

function getDemoHistoricalData(symbol, timeframe) {
    const days = getTimeframeDays(timeframe);
    const data = [];
    let price = 150 + Math.random() * 100;
    
    for (let i = days; i >= 0; i--) {
        const date = new Date();
        date.setDate(date.getDate() - i);
        
        // Skip weekends
        if (date.getDay() === 0 || date.getDay() === 6) continue;
        
        const change = (Math.random() - 0.5) * 5;
        price += change;
        
        const dayOpen = price + (Math.random() - 0.5) * 2;
        const dayHigh = Math.max(dayOpen, price) + Math.random() * 3;
        const dayLow = Math.min(dayOpen, price) - Math.random() * 3;
        
        data.push({
            date: date,
            open: dayOpen,
            high: dayHigh,
            low: dayLow,
            close: price,
            volume: Math.floor(Math.random() * 10000000) + 5000000
        });
    }
    
    return data;
}

// Display stock summary
function displayStockSummary(stockData) {
    document.getElementById('stockName').textContent = stockData.name;
    document.getElementById('stockSymbolDisplay').textContent = stockData.symbol;
    document.getElementById('currentPrice').textContent = formatPrice(stockData.price);
    
    const changeElement = document.getElementById('priceChange');
    const changePercentElement = document.getElementById('priceChangePercent');
    
    changeElement.textContent = formatChange(stockData.change);
    changePercentElement.textContent = `(${formatPercent(stockData.changePercent)})`;
    
    // Apply color classes
    const colorClass = stockData.change >= 0 ? 'positive' : 'negative';
    changeElement.className = colorClass;
    changePercentElement.className = colorClass;
    
    // Update summary cards
    document.getElementById('marketCap').textContent = stockData.marketCap;
    document.getElementById('peRatio').textContent = stockData.peRatio;
    document.getElementById('high52w').textContent = stockData.high52w;
    document.getElementById('low52w').textContent = stockData.low52w;
    document.getElementById('volume').textContent = stockData.volume;
    document.getElementById('avgVolume').textContent = stockData.avgVolume;
}

// Display portfolio section
function displayPortfolioSection() {
    // Reset portfolio inputs and results
    document.getElementById('sharesOwned').value = '';
    document.getElementById('avgPurchasePrice').value = '';
    document.getElementById('portfolioResults').classList.add('hidden');
}

// Calculate portfolio returns
function calculatePortfolio() {
    const shares = parseFloat(document.getElementById('sharesOwned').value) || 0;
    const avgPrice = parseFloat(document.getElementById('avgPurchasePrice').value) || 0;
    
    if (shares <= 0 || avgPrice <= 0) {
        showError('Please enter valid values for shares owned and average purchase price');
        return;
    }
    
    if (!currentStockData) {
        showError('Please search for a stock first');
        return;
    }
    
    const currentPrice = currentStockData.price;
    const totalInvestment = shares * avgPrice;
    const currentValue = shares * currentPrice;
    const totalGainLoss = currentValue - totalInvestment;
    const growthPercent = (totalGainLoss / totalInvestment) * 100;
    
    // Display results
    document.getElementById('totalInvestment').textContent = formatPrice(totalInvestment);
    document.getElementById('currentValue').textContent = formatPrice(currentValue);
    
    const gainLossElement = document.getElementById('totalGainLoss');
    const growthElement = document.getElementById('growthPercent');
    
    gainLossElement.textContent = formatChange(totalGainLoss);
    growthElement.textContent = formatPercent(growthPercent);
    
    // Apply color classes
    const colorClass = totalGainLoss >= 0 ? 'positive' : 'negative';
    gainLossElement.className = colorClass;
    growthElement.className = colorClass;
    
    document.getElementById('portfolioResults').classList.remove('hidden');
}

// Display chart
function displayChart(data, symbol) {
    const ctx = document.getElementById('priceChart').getContext('2d');
    
    // Destroy existing chart
    if (currentChart) {
        currentChart.destroy();
    }
    
    const labels = data.map(item => item.date.toLocaleDateString());
    const prices = data.map(item => item.close);
    
    currentChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: `${symbol} Price`,
                data: prices,
                borderColor: '#3b82f6',
                backgroundColor: 'rgba(59, 130, 246, 0.1)',
                borderWidth: 2,
                fill: true,
                tension: 0.1,
                pointBackgroundColor: '#3b82f6',
                pointBorderColor: '#ffffff',
                pointBorderWidth: 2,
                pointRadius: 0,
                pointHoverRadius: 6
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    labels: {
                        color: '#cbd5e1',
                        font: {
                            size: 14
                        }
                    }
                },
                tooltip: {
                    backgroundColor: 'rgba(26, 31, 46, 0.95)',
                    titleColor: '#f8fafc',
                    bodyColor: '#cbd5e1',
                    borderColor: '#334155',
                    borderWidth: 1,
                    cornerRadius: 8,
                    callbacks: {
                        label: function(context) {
                            return `Price: ${formatPrice(context.parsed.y)}`;
                        }
                    }
                }
            },
            scales: {
                x: {
                    grid: {
                        color: '#334155',
                        borderColor: '#334155'
                    },
                    ticks: {
                        color: '#cbd5e1',
                        maxTicksLimit: 10
                    }
                },
                y: {
                    grid: {
                        color: '#334155',
                        borderColor: '#334155'
                    },
                    ticks: {
                        color: '#cbd5e1',
                        callback: function(value) {
                            return formatPrice(value);
                        }
                    }
                }
            },
            interaction: {
                intersect: false,
                mode: 'index'
            }
        }
    });
}

// Display data table
function displayTable(data) {
    const tbody = document.getElementById('tableBody');
    tbody.innerHTML = '';
    
    // Show recent data first
    const reversedData = [...data].reverse();
    
    reversedData.forEach(item => {
        const row = tbody.insertRow();
        row.insertCell(0).textContent = item.date.toLocaleDateString();
        row.insertCell(1).textContent = formatPrice(item.open);
        row.insertCell(2).textContent = formatPrice(item.high);
        row.insertCell(3).textContent = formatPrice(item.low);
        row.insertCell(4).textContent = formatPrice(item.close);
        row.insertCell(5).textContent = formatLargeNumber(item.volume);
    });
}

// Change timeframe
async function changeTimeframe(timeframe) {
    if (!currentStockData) return;
    
    currentTimeframe = timeframe;
    
    // Update active button
    document.querySelectorAll('.chart-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    event.target.classList.add('active');
    
    showLoading(true);
    
    try {
        const historicalPrices = await fetchHistoricalData(currentStockData.symbol, timeframe);
        historicalData = historicalPrices;
        
        displayChart(historicalPrices, currentStockData.symbol);
        displayTable(historicalPrices);
    } catch (error) {
        showError('Failed to load data for selected timeframe');
    } finally {
        showLoading(false);
    }
}

// Download CSV
function downloadCSV() {
    if (!historicalData || historicalData.length === 0) {
        showError('No data available to download');
        return;
    }
    
    const headers = ['Date', 'Open', 'High', 'Low', 'Close', 'Volume'];
    const csvContent = [
        headers.join(','),
        ...historicalData.map(item => [
            item.date.toLocaleDateString(),
            item.open.toFixed(2),
            item.high.toFixed(2),
            item.low.toFixed(2),
            item.close.toFixed(2),
            item.volume
        ].join(','))
    ].join('\n');
    
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);
    link.setAttribute('href', url);
    link.setAttribute('download', `${currentStockData.symbol}_${currentTimeframe}_data.csv`);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}

// Utility functions
function getTimeframeRange(timeframe) {
    const ranges = {
        '1M': '1mo',
        '3M': '3mo',
        '6M': '6mo',
        '1Y': '1y'
    };
    return ranges[timeframe] || '1mo';
}

function getTimeframeDays(timeframe) {
    const days = {
        '1M': 30,
        '3M': 90,
        '6M': 180,
        '1Y': 365
    };
    return days[timeframe] || 30;
}

function formatPrice(price) {
    if (price === null || price === undefined) return 'N/A';
    return `$${parseFloat(price).toFixed(2)}`;
}

function formatChange(change) {
    if (change === null || change === undefined) return 'N/A';
    const sign = change >= 0 ? '+' : '';
    return `${sign}$${parseFloat(change).toFixed(2)}`;
}

function formatPercent(percent) {
    if (percent === null || percent === undefined) return 'N/A';
    const sign = percent >= 0 ? '+' : '';
    return `${sign}${parseFloat(percent).toFixed(2)}%`;
}

function formatLargeNumber(num) {
    if (num === null || num === undefined) return 'N/A';
    
    const number = parseFloat(num);
    if (number >= 1e12) return (number / 1e12).toFixed(2) + 'T';
    if (number >= 1e9) return (number / 1e9).toFixed(2) + 'B';
    if (number >= 1e6) return (number / 1e6).toFixed(2) + 'M';
    if (number >= 1e3) return (number / 1e3).toFixed(2) + 'K';
    return number.toLocaleString();
}

function showLoading(show) {
    document.getElementById('loading').classList.toggle('hidden', !show);
    document.getElementById('searchBtn').disabled = show;
}

function showAllSections() {
    document.getElementById('stockSummary').classList.remove('hidden');
    document.getElementById('portfolioSection').classList.remove('hidden');
    document.getElementById('chartSection').classList.remove('hidden');
    document.getElementById('tableSection').classList.remove('hidden');
}

function hideAllSections() {
    document.getElementById('stockSummary').classList.add('hidden');
    document.getElementById('portfolioSection').classList.add('hidden');
    document.getElementById('chartSection').classList.add('hidden');
    document.getElementById('tableSection').classList.add('hidden');
}

function showError(message) {
    document.getElementById('errorMessage').textContent = message;
    document.getElementById('errorModal').classList.remove('hidden');
}

function closeModal() {
    document.getElementById('errorModal').classList.add('hidden');
}

// Close modal when clicking outside
window.onclick = function(event) {
    const modal = document.getElementById('errorModal');
    if (event.target === modal) {
        closeModal();
    }
}