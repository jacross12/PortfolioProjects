-- Select data to be used
SELECT 
	location,
    date,
    total_cases,
    new_cases,
    total_deaths,
    population
FROM covid_deaths
ORDER BY location, date;

-- Change date type and format
ALTER TABLE covid_deaths
MODIFY date varchar(255);
UPDATE covid_deaths
SET date=STR_TO_DATE(date,"%m/%d/%Y");

ALTER TABLE covid_vaccinations
MODIFY date varchar(255);
UPDATE covid_vaccinations
SET date=STR_TO_DATE(date,"%m/%d/%Y");

-- Looking at Total Cases vs Total Deaths
-- Shows likeihood of dying if you contract COVID in your country
SELECT 
	location,
    date,
    total_cases,
    total_deaths,
    (total_deaths/total_cases)*100 AS death_percentage
FROM covid_deaths
ORDER BY location, date;

-- Looking at Total Cases vs Population
-- Shows what percentage of population got COVID
SELECT 
	location,
    date,
    total_cases,
    population,
    (total_cases/population)*100 AS covid_infection_percentage
FROM covid_deaths
WHERE location LIKE '%states%'
ORDER BY location, date;

-- Looking at contries with highest infection rate compared to population
SELECT 
	location,
    population,
    MAX(total_cases) AS highest_infected_count,
    (MAX(total_cases)/population)*100 AS percent_population_infected
FROM covid_deaths
GROUP BY location, population
ORDER BY percent_population_infected DESC;

-- Showing countries with highest death count per population
-- converts total_deaths from text to int
SELECT 
	location,
    population,
    MAX(CONVERT(IFNULL(total_deaths, 0), SIGNED)) AS total_death_count,
    (MAX(CONVERT(IFNULL(total_deaths, 0), SIGNED))/population)*100 AS percent_death_population
FROM covid_deaths
GROUP BY location, population
ORDER BY percent_death_population DESC;

-- Showing deaths by continent
SELECT 
    continent,
    MAX(CONVERT(IFNULL(total_deaths, 0), SIGNED)) AS total_death_count
FROM covid_deaths
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY total_death_count DESC;

-- Global numbers
SELECT
	date,
    total_cases,
    total_deaths,
    (total_deaths/total_cases)*100 as death_percentage
FROM covid_deaths
WHERE continent IS NOT NULL
ORDER BY date, total_cases;

-- Overall death percentage
SELECT
	SUM(new_cases) as total_cases,
    SUM(CONVERT(IFNULL(new_deaths, 0), SIGNED)) as total_deaths,
    SUM(CONVERT(IFNULL(new_deaths, 0), SIGNED))/SUM(new_cases)*100 as DeathPercentage
FROM covid_deaths
WHERE continent IS NOT NULL;

-- Looking at total population vs vaccinations
SELECT 
	cd.continent,
    cd.location,
    cd.date,
    cd.population,
    cv.new_vaccinations,
    SUM(CONVERT(IFNULL(cv.new_vaccinations, 0), SIGNED)) OVER (Partition by cd.location ORDER BY cd.location, cd.date) AS rolling_vaccination_count
FROM covid_deaths cd
JOIN covid_vaccinations cv
	ON cd.location = cv.location 
    AND cd.date= cv.date
WHERE cd.continent IS NOT NULL
ORDER BY cd.location, cd.date;

-- USE CTE
With pop_vs_vac (continent, location, date, population, new_vaccinations, rolling_vaccination_count)
AS
(
SELECT 
	cd.continent,
    cd.location,
    cd.date,
    cd.population,
    cv.new_vaccinations,
    SUM(CONVERT(IFNULL(cv.new_vaccinations, 0), SIGNED)) OVER (Partition by cd.location ORDER BY cd.location, cd.date) AS rolling_vaccination_count
FROM covid_deaths cd
JOIN covid_vaccinations cv
	ON cd.location = cv.location 
    AND cd.date= cv.date
WHERE cd.continent IS NOT NULL
)
SELECT *, (rolling_vaccination_count/population)*100
FROM pop_vs_vac;

-- Convert text to bigint
UPDATE covid_vaccinations SET new_vaccinations = NULL WHERE new_vaccinations = '';
ALTER TABLE covid_vaccinations MODIFY new_vaccinations BIGINT UNSIGNED DEFAULT NULL;
UPDATE covid_vaccinations SET new_vaccinations = CAST(new_vaccinations AS UNSIGNED) WHERE new_vaccinations REGEXP '^[0-9]+$';

-- Temp Table
DROP TABLE if exists percent_pop_vaccinated;
CREATE TEMPORARY TABLE percent_pop_vaccinated
(continent nvarchar(255),
location nvarchar(255),
date datetime,
population numeric,
new_vaccinations numeric,
rolling_people_vaccinated numeric
);

INSERT INTO percent_pop_vaccinated 
SELECT   
	cd.continent,     
	cd.location,     
	cd.date,     
	cd.population,     
	cv.new_vaccinations,     
	(SELECT SUM(cv.new_vaccinations) FROM covid_vaccinations cv WHERE cv.location = cd.location AND cv.date = cd.date) AS rolling_vaccination_count 
FROM 
	covid_deaths cd 
	JOIN covid_vaccinations cv  ON cd.location = cv.location AND cd.date = cv.date 
WHERE 
	cd.continent IS NOT NULL;

SELECT *, (rolling_vaccination_count/population)*100
FROM percent_pop_vaccinated;


-- Creating view to store data for later visualizations

CREATE VIEW TotalDeath AS
SELECT
	SUM(new_cases) as total_cases,
    SUM(CONVERT(IFNULL(new_deaths, 0), SIGNED)) as total_deaths,
    SUM(CONVERT(IFNULL(new_deaths, 0), SIGNED))/SUM(new_cases)*100 as DeathPercentage
FROM covid_deaths
WHERE continent IS NOT NULL;

CREATE VIEW TotalPopvsVac AS
SELECT 
	cd.continent,
    cd.location,
    cd.date,
    cd.population,
    cv.new_vaccinations,
    SUM(CONVERT(IFNULL(cv.new_vaccinations, 0), SIGNED)) OVER (Partition by cd.location ORDER BY cd.location, cd.date) AS rolling_vaccination_count
FROM covid_deaths cd
JOIN covid_vaccinations cv
	ON cd.location = cv.location 
    AND cd.date= cv.date
WHERE cd.continent IS NOT NULL
ORDER BY cd.location, cd.date;

CREATE VIEW TotalCasesvsTotalDeaths AS
SELECT 
	location,
    date,
    total_cases,
    total_deaths,
    (total_deaths/total_cases)*100 AS death_percentage
FROM covid_deaths
ORDER BY location, date;

CREATE VIEW TotalCasesvsPop AS
SELECT 
	location,
    date,
    total_cases,
    population,
    (total_cases/population)*100 AS covid_infection_percentage
FROM covid_deaths
WHERE location LIKE '%states%'
ORDER BY location, date;

CREATE VIEW InfectionRatebyPop AS
SELECT 
	location,
    population,
    MAX(total_cases) AS highest_infected_count,
    (MAX(total_cases)/population)*100 AS percent_population_infected
FROM covid_deaths
GROUP BY location, population
ORDER BY percent_population_infected DESC;

CREATE VIEW DeathCountperPop AS
SELECT 
	location,
    population,
    MAX(CONVERT(IFNULL(total_deaths, 0), SIGNED)) AS total_death_count,
    (MAX(CONVERT(IFNULL(total_deaths, 0), SIGNED))/population)*100 AS percent_death_population
FROM covid_deaths
GROUP BY location, population
ORDER BY percent_death_population DESC;

CREATE VIEW deathbyCont AS
SELECT 
    continent,
    MAX(CONVERT(IFNULL(total_deaths, 0), SIGNED)) AS total_death_count
FROM covid_deaths
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY total_death_count DESC;