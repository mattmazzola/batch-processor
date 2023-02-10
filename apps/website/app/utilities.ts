export function getRandom(max: number, min: number = 0) {
    if (max < min) {
        throw new Error(`You attempted to get a random value between range where max: ${max} is less than the min: ${min}`)
    }

    const random = Math.floor(Math.random() * max)
    const offsetRandom = random + min

    return offsetRandom
}
