
package org.apache.lucene.codecs;

import org.apache.lucene.codecs.Codec;
import org.apache.lucene.codecs.FilterCodec;
import org.apache.lucene.codecs.PostingsFormat;
import org.apache.lucene.codecs.lucene95.Lucene95Codec;

/**
 *  * This is a Javadoc comment for the NoCompressionCodec class.
 *   * It should provide a description of the class.
 *    @see org.apache.lucene.codecs.lucene95 package documentation for file format details.
 *     * @lucene.experimental
 *    */


public class NoCompressionCodec extends FilterCodec {
    public NoCompressionCodec() {
        super("NoCompressionCodec", new Lucene95Codec());
    }

    @Override
    public PostingsFormat postingsFormat() {
        return PostingsFormat.forName("Direct");
    }
}
