/// Jeu du moulin (Nine Men's Morris). Plateau à 24 intersections.
///
///     0-----------1-----------2
///     |           |           |
///     |   3-------4-------5   |
///     |   |       |       |   |
///     |   |   6---7---8   |   |
///     |   |   |       |   |   |
///     9--10--11      12--13--14
///     |   |   |       |   |   |
///     |   |  15--16--17   |   |
///     |   |       |       |   |
///     |  18------19------20   |
///     |           |           |
///     21---------22----------23
public enum MillPlayer: String, Sendable, Hashable, CaseIterable {
    case white
    case black

    public var opponent: MillPlayer { self == .white ? .black : .white }
    public var localizationKey: String { "mill.player.\(rawValue)" }
}

public enum MillBoard {
    public static let pointCount = 24
    public static let menPerPlayer = 9

    /// Les 16 alignements de trois.
    public static let mills: [[Int]] = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8], [9, 10, 11],
        [12, 13, 14], [15, 16, 17], [18, 19, 20], [21, 22, 23],
        [0, 9, 21], [3, 10, 18], [6, 11, 15], [1, 4, 7],
        [16, 19, 22], [8, 12, 17], [5, 13, 20], [2, 14, 23],
    ]

    /// Intersections voisines, reliées par un trait du plateau.
    public static let adjacency: [[Int]] = [
        /* 0 */ [1, 9],        /* 1 */ [0, 2, 4],      /* 2 */ [1, 14],
        /* 3 */ [4, 10],       /* 4 */ [1, 3, 5, 7],   /* 5 */ [4, 13],
        /* 6 */ [7, 11],       /* 7 */ [4, 6, 8],      /* 8 */ [7, 12],
        /* 9 */ [0, 10, 21],   /* 10 */ [3, 9, 11, 18],/* 11 */ [6, 10, 15],
        /* 12 */ [8, 13, 17],  /* 13 */ [5, 12, 14, 20], /* 14 */ [2, 13, 23],
        /* 15 */ [11, 16],     /* 16 */ [15, 17, 19],  /* 17 */ [12, 16, 20],
        /* 18 */ [10, 19],     /* 19 */ [16, 18, 20, 22], /* 20 */ [13, 17, 19],
        /* 21 */ [9, 22],      /* 22 */ [19, 21, 23],  /* 23 */ [14, 22],
    ]

    /// Les alignements passant par une intersection donnée, précalculés.
    public static let millsThrough: [[[Int]]] = (0..<pointCount).map { point in
        mills.filter { $0.contains(point) }
    }
}
