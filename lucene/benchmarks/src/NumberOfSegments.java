import java.io.IOException;
import java.nio.file.FileSystems;

import org.apache.lucene.index.SegmentInfos;
import org.apache.lucene.store.FSDirectory;

public class NumberOfSegments {
    public static void main(String[] args) throws IOException {
        if (args.length != 1) {
            System.out.println("Usage: java NumberOfSegments INDEX_DIR");
            System.exit(0);
        }

        System.out.println("Number of segments: " + SegmentInfos.readLatestCommit(FSDirectory.open(FileSystems.getDefault().getPath(args[0]))).size());
    }
}
