class World {
    String name;
    List<Level> levels;
    int currentLevelIndex = 0;

    World(this.name, this.levels);

    Level get currentLevel {
        return levels[currentLevelIndex];
    }

    void advanceToNextLevel() {
        if (currentLevelIndex < levels.length - 1) {
            currentLevelIndex++;
        }
    }

    bool isCompleted() {
        return currentLevelIndex == levels.length - 1;
    }
}

class Level {
    String title;
    String description;
    int difficulty;

    Level(this.title, this.description, this.difficulty);
}