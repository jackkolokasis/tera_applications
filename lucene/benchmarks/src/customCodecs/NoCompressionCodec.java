package customCodecs;

import org.apache.lucene.codecs.Codec;
import org.apache.lucene.codecs.FilterCodec;
import org.apache.lucene.codecs.PostingsFormat;
import org.apache.lucene.codecs.lucene95.Lucene95Codec;

public class NoCompressionCodec extends FilterCodec {
    public NoCompressionCodec() {
        super("NoCompressionCodec", new Lucene95Codec());
    }

    @Override
    public PostingsFormat postingsFormat() {
        return PostingsFormat.forName("Direct");
    }
}
